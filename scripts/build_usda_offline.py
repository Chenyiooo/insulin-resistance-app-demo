"""Build a compact, reproducible food lookup from official USDA JSON archives."""

from __future__ import annotations

import argparse
import json
import sqlite3
import zipfile
from pathlib import Path


DATASETS = (
    ("FoundationFoods", "Foundation"),
    ("SRLegacyFoods", "SR Legacy"),
    ("SurveyFoods", "Survey (FNDDS)"),
)
NUTRIENTS = {1003: "protein", 1004: "fat", 1005: "carbohydrates"}
ENERGY_IDS = (1008, 2047, 2048)


def _records(archive: Path, key: str):
    with zipfile.ZipFile(archive) as source:
        members = [name for name in source.namelist() if name.endswith(".json")]
        if len(members) != 1:
            raise ValueError(f"Expected one JSON file in {archive}")
        with source.open(members[0]) as handle:
            records = json.load(handle).get(key)
    if not isinstance(records, list):
        raise ValueError(f"Missing {key} in {archive}")
    return records


def _nutrient_values(food: dict) -> dict[str, float]:
    amounts: dict[int, float] = {}
    for item in food.get("foodNutrients", []):
        nutrient = item.get("nutrient", {})
        nutrient_id = nutrient.get("id")
        amount = item.get("amount")
        if nutrient_id in (*ENERGY_IDS, *NUTRIENTS) and isinstance(amount, (int, float)) and amount >= 0:
            amounts[nutrient_id] = float(amount)
    energy = next((amounts[value] for value in ENERGY_IDS if value in amounts), None)
    if energy is None or any(value not in amounts for value in NUTRIENTS):
        return {}
    return {"calories": energy, **{name: amounts[key] for key, name in NUTRIENTS.items()}}


def build(archives: list[Path], output: Path) -> dict[str, int]:
    if len(archives) != len(DATASETS):
        raise ValueError("Pass Foundation, SR Legacy, and FNDDS archives in that order")
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    counts: dict[str, int] = {}
    with sqlite3.connect(output) as database:
        database.execute(
            "CREATE TABLE foods (fdc_id INTEGER PRIMARY KEY, description TEXT NOT NULL, data_type TEXT NOT NULL, calories REAL NOT NULL, carbohydrates REAL NOT NULL, protein REAL NOT NULL, fat REAL NOT NULL)"
        )
        database.execute("CREATE VIRTUAL TABLE foods_fts USING fts5(description, content='foods', content_rowid='fdc_id', tokenize='porter unicode61')")
        for archive, (key, data_type) in zip(archives, DATASETS):
            rows = []
            for food in _records(archive, key):
                if not isinstance(food, dict):
                    continue
                nutrients = _nutrient_values(food)
                fdc_id = food.get("fdcId")
                description = food.get("description")
                if not nutrients or not isinstance(fdc_id, int) or not isinstance(description, str):
                    continue
                rows.append((fdc_id, description, data_type, *(nutrients[name] for name in ("calories", "carbohydrates", "protein", "fat"))))
            database.executemany("INSERT INTO foods VALUES (?, ?, ?, ?, ?, ?, ?)", rows)
            counts[data_type] = len(rows)
        database.execute("INSERT INTO foods_fts(foods_fts) VALUES('rebuild')")
        database.commit()
        database.execute("VACUUM")
    return counts


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("foundation", type=Path)
    parser.add_argument("sr_legacy", type=Path)
    parser.add_argument("fndds", type=Path)
    parser.add_argument("--output", type=Path, default=Path("backend/data/usda_foods.sqlite"))
    args = parser.parse_args()
    print(build([args.foundation, args.sr_legacy, args.fndds], args.output))
