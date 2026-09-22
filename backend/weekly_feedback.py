from __future__ import annotations

from datetime import date, timedelta
from typing import Any

from backend.service import ModelInputError, RiskPredictionService, prediction_to_dict


AVERAGED_FEATURES = (
    "weight", "waist_circumference", "systolic_bp", "diastolic_bp", "sleep_hours"
)


def build_weekly_feedback(
    checkins: list[dict[str, Any]], service: RiskPredictionService
) -> dict[str, Any]:
    # The database returns newest entries first, including multiple edits on one date.
    completed_by_day: dict[date, dict[str, Any]] = {}
    for record in checkins:
        if record.get("data", {}).get("isCompleted") is not True:
            continue
        try:
            day = date.fromisoformat(record["checkin_date"])
        except (KeyError, TypeError, ValueError):
            continue
        completed_by_day.setdefault(day, record)

    if not completed_by_day:
        return _response("waiting", None, None, 0, 0)

    first_day = min(completed_by_day)
    last_day = max(completed_by_day)
    elapsed_days = (last_day - first_day).days + 1
    milestone = 14 if elapsed_days >= 14 else 7 if elapsed_days >= 7 else None
    if milestone is None:
        return _response("waiting", first_day, None, len(completed_by_day), 7)

    window = [first_day + timedelta(days=offset) for offset in range(milestone)]
    records = [completed_by_day[day] for day in window if day in completed_by_day]
    if len(records) != milestone:
        return _response("incomplete", first_day, milestone, len(records), milestone)

    payloads = [record.get("model_payload") or {} for record in records]
    if any(not isinstance(payload.get("features"), dict) for payload in payloads):
        return _response("unavailable", first_day, milestone, milestone, milestone)

    features = dict(payloads[-1]["features"])
    averages: dict[str, float] = {}
    counts: dict[str, int] = {}
    for key in AVERAGED_FEATURES:
        values = [payload["features"].get(key) for payload in payloads]
        numeric = [float(value) for value in values if isinstance(value, (int, float)) and not isinstance(value, bool)]
        if numeric:
            averages[key] = sum(numeric) / len(numeric)
            counts[key] = len(numeric)
            features[key] = averages[key]
        else:
            features.pop(key, None)

    height = features.get("height")
    if isinstance(height, (int, float)) and height > 0:
        if "weight" in averages:
            features["bmi"] = averages["weight"] / (height / 100) ** 2
        if "waist_circumference" in averages:
            features["waist_height_ratio"] = averages["waist_circumference"] / height

    try:
        result = prediction_to_dict(
            service.predict(
                {"features": features},
                recent_checkins=[payload["features"] for payload in payloads],
            )
        )
    except (ModelInputError, ValueError):
        return _response("unavailable", first_day, milestone, milestone, milestone)

    response = _response("ready", first_day, milestone, milestone, milestone)
    response.update(
        risk_result=result,
        averaged_features=averages,
        measurement_counts=counts,
        period_end=window[-1].isoformat(),
        period_checkins=[
            {"checkin_date": record["checkin_date"], "data": record["data"]}
            for record in records
        ],
    )
    return response


def _response(
    status: str, first_day: date | None, milestone: int | None, completed_days: int, required_days: int
) -> dict[str, Any]:
    return {
        "status": status,
        "first_checkin_date": first_day.isoformat() if first_day else None,
        "milestone_day": milestone,
        "completed_days": completed_days,
        "required_days": required_days,
        "risk_result": None,
        "averaged_features": {},
        "measurement_counts": {},
        "period_end": None,
        "period_checkins": [],
    }
