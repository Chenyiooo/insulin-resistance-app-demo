#!/usr/bin/env python3
"""Export participant check-in completion reports from the study database."""

from __future__ import annotations

import argparse
import csv
import getpass
import json
import os
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import psycopg


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path.home() / "ir-study-exports",
        help="Directory where export files will be saved.",
    )
    return parser.parse_args()


def parse_json(value: object) -> dict:
    if isinstance(value, dict):
        return value
    if not value:
        return {}
    try:
        parsed = json.loads(str(value))
        return parsed if isinstance(parsed, dict) else {}
    except (TypeError, ValueError, json.JSONDecodeError):
        return {}


def as_date(value: object) -> date:
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    return date.fromisoformat(str(value)[:10])


def daterange(start: date, end: date):
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    database_url = os.environ.get("IR_DATABASE_URL") or getpass.getpass(
        "Paste the Render External Database URL (input is hidden): "
    )
    if not database_url:
        raise SystemExit("No database URL was provided.")

    with psycopg.connect(database_url) as connection:
        connection.execute("SET TRANSACTION READ ONLY")
        users = connection.execute(
            "SELECT id, email, name, created_at FROM users ORDER BY created_at"
        ).fetchall()
        checkins = connection.execute(
            """
            SELECT id, user_id, checkin_date, source, provenance_json, data_json,
                   model_payload_json, risk_result_json, created_at, updated_at
            FROM checkins
            ORDER BY user_id, checkin_date, updated_at
            """
        ).fetchall()

    today = date.today()
    closed_period_end = today - timedelta(days=1)
    by_user_day: dict[str, dict[date, list[dict]]] = defaultdict(
        lambda: defaultdict(list)
    )
    raw_checkins = []

    for row in checkins:
        (
            checkin_id,
            user_id,
            checkin_date,
            source,
            provenance_json,
            data_json,
            model_payload_json,
            risk_result_json,
            created_at,
            updated_at,
        ) = row
        payload = parse_json(data_json)
        record = {
            "id": checkin_id,
            "user_id": user_id,
            "checkin_date": as_date(checkin_date).isoformat(),
            "source": source,
            "provenance": parse_json(provenance_json),
            "data": payload,
            "model_payload": parse_json(model_payload_json),
            "risk_result": parse_json(risk_result_json),
            "created_at": str(created_at),
            "updated_at": str(updated_at),
        }
        raw_checkins.append(record)
        by_user_day[str(user_id)][as_date(checkin_date)].append(record)

    summary_rows = []
    daily_rows = []
    missing_rows = []
    raw_users = []

    for user_id, email, name, created_at in users:
        user_id = str(user_id)
        raw_users.append(
            {
                "id": user_id,
                "email": email,
                "name": name,
                "created_at": str(created_at),
            }
        )
        days = by_user_day.get(user_id, {})
        all_dates = sorted(days)
        first_date = all_dates[0] if all_dates else None
        last_date = all_dates[-1] if all_dates else None
        completed_closed_days = 0
        missing_closed_days = 0
        expected_closed_days = 0

        if first_date:
            for day in daterange(first_date, today):
                records = days.get(day, [])
                completed = any(
                    record["data"].get("isCompleted") is True for record in records
                )
                if day == today and not completed:
                    status = "pending_today"
                elif completed:
                    status = "completed"
                elif records:
                    status = "incomplete"
                else:
                    status = "missing"

                daily_rows.append(
                    {
                        "participant_id": user_id,
                        "email": email,
                        "name": name or "",
                        "date": day.isoformat(),
                        "status": status,
                        "submission_count": len(records),
                    }
                )

                if day <= closed_period_end:
                    expected_closed_days += 1
                    if completed:
                        completed_closed_days += 1
                    else:
                        missing_closed_days += 1
                        missing_rows.append(
                            {
                                "participant_id": user_id,
                                "email": email,
                                "name": name or "",
                                "missing_date": day.isoformat(),
                                "status": status,
                            }
                        )

        completion_rate = (
            round(completed_closed_days / expected_closed_days * 100, 1)
            if expected_closed_days
            else ""
        )
        today_completed = any(
            record["data"].get("isCompleted") is True
            for record in days.get(today, [])
        )
        summary_rows.append(
            {
                "participant_id": user_id,
                "email": email,
                "name": name or "",
                "account_created_at": str(created_at),
                "first_checkin_date": first_date.isoformat() if first_date else "",
                "last_checkin_date": last_date.isoformat() if last_date else "",
                "closed_period_end": closed_period_end.isoformat(),
                "expected_closed_days": expected_closed_days,
                "completed_closed_days": completed_closed_days,
                "missing_closed_days": missing_closed_days,
                "completion_rate_pct": completion_rate,
                "today_status": "completed" if today_completed else "pending",
                "total_checkin_records": sum(len(records) for records in days.values()),
            }
        )

    args.output_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")
    summary_path = args.output_dir / f"participant-summary-{stamp}.csv"
    daily_path = args.output_dir / f"participant-daily-status-{stamp}.csv"
    missing_path = args.output_dir / f"participant-missing-days-{stamp}.csv"
    raw_path = args.output_dir / f"study-data-{stamp}.json"

    write_csv(summary_path, list(summary_rows[0]) if summary_rows else [], summary_rows)
    write_csv(daily_path, list(daily_rows[0]) if daily_rows else [], daily_rows)
    write_csv(missing_path, list(missing_rows[0]) if missing_rows else [
        "participant_id", "email", "name", "missing_date", "status"
    ], missing_rows)
    raw_path.write_text(
        json.dumps(
            {
                "exported_at": datetime.now(timezone.utc).isoformat(),
                "users": raw_users,
                "checkins": raw_checkins,
            },
            indent=2,
            default=str,
        ),
        encoding="utf-8",
    )

    print(f"Saved summary: {summary_path}")
    print(f"Saved daily report: {daily_path}")
    print(f"Saved missing-day report: {missing_path}")
    print(f"Saved raw data: {raw_path}")
    print(
        f"Participants: {len(summary_rows)}; check-in records: {len(raw_checkins)}; "
        f"missing closed days: {len(missing_rows)}"
    )


if __name__ == "__main__":
    main()
