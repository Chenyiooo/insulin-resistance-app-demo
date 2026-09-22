from datetime import date, timedelta
import os
import tempfile
from unittest.mock import patch

from backend.service import RiskPredictionService
from backend import storage
from backend.weekly_feedback import build_weekly_feedback
from tests.test_backend_service import complete_features


SERVICE = RiskPredictionService()


def record(day: date, sleep: float, weight: float = 67.1, completed: bool = True):
    features = complete_features()
    features["sleep_hours"] = sleep
    features["weight"] = weight
    features["bmi"] = weight / (features["height"] / 100) ** 2
    return {
        "checkin_date": day.isoformat(),
        "data": {"isCompleted": completed},
        "model_payload": {"features": features},
    }


def test_seventh_day_uses_seven_day_mean_regardless_of_weekday():
    start = date(2026, 9, 22)
    records = [record(start + timedelta(days=i), 6 + i, 65 + i) for i in range(7)]
    assert build_weekly_feedback(list(reversed(records[:6])), SERVICE)["status"] == "waiting"

    with patch.object(SERVICE, "predict", wraps=SERVICE.predict) as predict:
        result = build_weekly_feedback(list(reversed(records)), SERVICE)
    assert predict.call_args.args[0]["features"]["sleep_hours"] == 9
    assert predict.call_args.args[0]["features"]["weight"] == 68
    assert predict.call_args.args[0]["features"]["bmi"] == 68 / (1.676 ** 2)
    assert result["status"] == "ready"
    assert result["milestone_day"] == 7
    assert result["first_checkin_date"] == start.isoformat()
    assert result["averaged_features"]["sleep_hours"] == 9
    assert result["averaged_features"]["weight"] == 68
    assert result["measurement_counts"]["sleep_hours"] == 7
    assert result["risk_result"]["model_name"] == "reduced_lightgbm"


def test_fourteenth_day_uses_all_fourteen_days_not_just_latest_seven():
    start = date(2026, 9, 22)
    records = [record(start + timedelta(days=i), 6 if i < 7 else 8) for i in range(14)]
    result = build_weekly_feedback(list(reversed(records)), SERVICE)
    assert result["status"] == "ready"
    assert result["milestone_day"] == 14
    assert result["averaged_features"]["sleep_hours"] == 7
    assert result["measurement_counts"]["sleep_hours"] == 14


def test_gap_or_draft_does_not_unlock_feedback():
    start = date(2026, 9, 22)
    records = [record(start + timedelta(days=i), 7, completed=i != 3) for i in range(7)]
    result = build_weekly_feedback(list(reversed(records)), SERVICE)
    assert result["status"] == "incomplete"
    assert result["completed_days"] == 6


def test_same_day_edits_count_once_and_latest_edit_wins():
    start = date(2026, 9, 22)
    records = [record(start + timedelta(days=i), 7) for i in range(7)]
    latest_edit = record(start + timedelta(days=6), 14)
    result = build_weekly_feedback([latest_edit, *reversed(records)], SERVICE)
    assert result["status"] == "ready"
    assert result["averaged_features"]["sleep_hours"] == 8


def test_weight_mean_uses_actual_measurement_days():
    start = date(2026, 9, 22)
    records = [record(start + timedelta(days=i), 7) for i in range(7)]
    for item in records[1:6]:
        item["model_payload"]["features"].pop("weight")
    records[-1]["model_payload"]["features"]["weight"] = 69.1
    result = build_weekly_feedback(list(reversed(records)), SERVICE)
    assert result["status"] == "ready"
    assert result["measurement_counts"]["weight"] == 2
    assert result["averaged_features"]["weight"] == 68.1


def test_endpoint_only_uses_authenticated_account_history():
    with tempfile.TemporaryDirectory() as tmpdir:
        previous = os.environ.get("IR_APP_DB_PATH")
        os.environ["IR_APP_DB_PATH"] = os.path.join(tmpdir, "weekly.db")
        try:
            from backend.main import get_my_weekly_feedback

            storage.init_db()
            first = storage.create_user("weekly-first@example.com", "password123")
            second = storage.create_user("weekly-second@example.com", "password123")
            start = date(2026, 9, 22)
            for offset in range(7):
                item = record(start + timedelta(days=offset), 7 + offset)
                storage.save_checkin(
                    first["id"], item["checkin_date"], item["data"], item["model_payload"]
                )
            assert get_my_weekly_feedback(current=first)["status"] == "ready"
            assert get_my_weekly_feedback(current=second)["status"] == "waiting"
        finally:
            if previous is None:
                os.environ.pop("IR_APP_DB_PATH", None)
            else:
                os.environ["IR_APP_DB_PATH"] = previous
