from __future__ import annotations

import base64
import logging
import os
import re
import sqlite3
from contextlib import closing
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path
from typing import Any

from backend.food_vision import MODEL_NAME, model_available, recognize_foods


logger = logging.getLogger(__name__)

DISCLAIMER = (
    "Nutrition values are estimates for reflection only, not medical or dietary advice. "
    "Values are calculated from USDA FoodData Central matches when available; accuracy "
    "depends on food identification, portion size, recipe, and preparation method."
)

USDA_DATA_TYPES = ("Survey (FNDDS)", "Foundation", "SR Legacy")
USDA_OFFLINE_DB = Path(__file__).resolve().parent / "data" / "usda_foods.sqlite"
NUTRIENT_IDS = {
    "calories": 1008,
    "protein": 1003,
    "fat": 1004,
    "carbohydrates": 1005,
}

LAST_NUTRITION_STATUS: dict[str, Any] = {
    "food_vision_attempted": False,
    "food_vision_ok": False,
    "food_vision_last_error_type": "not_attempted",
    "offline_lookup_attempted": False,
    "offline_lookup_ok": False,
    "offline_lookup_last_error_type": "not_attempted",
}


@dataclass(frozen=True)
class ParsedFood:
    query: str
    quantity: float = 1.0
    unit: str = "serving"
    raw_text: str = ""

    @property
    def estimated_grams(self) -> float:
        return _estimated_grams(self.quantity, self.unit, self.query)


def estimate_nutrition(text: str = "", image_base64: list[str] | None = None) -> dict[str, Any]:
    images = image_base64 or []
    parsed_foods = _parse_food_text(text)

    if images:
        if model_available():
            LAST_NUTRITION_STATUS.update(food_vision_attempted=True, food_vision_ok=False)
            try:
                predictions = recognize_foods(images)
                described = {food.query.casefold() for food in parsed_foods}
                parsed_foods.extend(
                    ParsedFood(query=name, quantity=grams, unit="g")
                    for name, grams in predictions if name.casefold() not in described
                )
                LAST_NUTRITION_STATUS.update(food_vision_ok=bool(predictions), food_vision_last_error_type=None if predictions else "no_confident_food")
            except Exception as exc:
                LAST_NUTRITION_STATUS["food_vision_last_error_type"] = type(exc).__name__
                logger.exception("Local food vision inference failed")
        else:
            LAST_NUTRITION_STATUS.update(food_vision_attempted=False, food_vision_ok=False, food_vision_last_error_type="not_configured")

    deduped_foods = _dedupe_foods(parsed_foods)
    if not deduped_foods:
        return _format_result(
            calories=0,
            carbohydrates=0,
            protein=0,
            fat=0,
            matched_foods=[],
            source="unable_to_estimate",
            confidence="low",
            explanation="No recognizable food and portion information was found.",
        )

    usda_result = _estimate_with_usda(deduped_foods)
    if usda_result:
        if images and LAST_NUTRITION_STATUS["food_vision_ok"]:
            usda_result["confidence"] = "low"
            usda_result["explanation"] += " Photo food identity and weight are low-confidence model estimates; verify the meal and portion."
        return usda_result

    return _format_result(
        calories=0,
        carbohydrates=0,
        protein=0,
        fat=0,
        matched_foods=[],
        source="unable_to_estimate",
        confidence="low",
        explanation=(
            "Food items were detected, but no usable match was found in the bundled "
            "USDA FoodData Central dataset."
        ),
    )


def _parse_food_text(text: str) -> list[ParsedFood]:
    cleaned = text.strip()
    if not cleaned:
        return []

    parsed_with_library = _parse_with_ingredient_parser(cleaned)
    if parsed_with_library:
        return parsed_with_library

    return [_parse_food_fragment(fragment) for fragment in _food_fragments(cleaned)]


def _parse_with_ingredient_parser(text: str) -> list[ParsedFood]:
    try:
        from ingredient_parser import parse_ingredient  # type: ignore
    except ImportError:
        return []

    foods: list[ParsedFood] = []
    for fragment in _food_fragments(text):
        try:
            parsed = parse_ingredient(fragment)
        except Exception as exc:  # pragma: no cover - defensive around optional dependency
            logger.debug("ingredient-parser failed for %r: %s", fragment, exc)
            continue

        query = _first_parser_text(getattr(parsed, "name", None))
        if not query:
            continue
        quantity, unit = _first_parser_amount(getattr(parsed, "amount", None))
        foods.append(
            ParsedFood(
                query=_clean_food_query(query),
                quantity=quantity,
                unit=unit,
                raw_text=fragment,
            )
        )
    return [food for food in foods if food.query]


def _first_parser_text(value: Any) -> str:
    if not value:
        return ""
    first = value[0] if isinstance(value, list) else value
    return str(getattr(first, "text", first)).strip()


def _first_parser_amount(value: Any) -> tuple[float, str]:
    if not value:
        return 1.0, "serving"
    first = value[0] if isinstance(value, list) else value
    quantity = getattr(first, "quantity", 1)
    unit = getattr(first, "unit", "serving")
    try:
        parsed_quantity = float(quantity)
    except (TypeError, ValueError):
        try:
            parsed_quantity = float(Fraction(str(quantity)))
        except (ValueError, ZeroDivisionError):
            parsed_quantity = 1.0
    return max(parsed_quantity, 0.25), str(unit or "serving")


def _food_fragments(text: str) -> list[str]:
    normalized = re.sub(r"\b(i ate|i had|ate|had|for breakfast|for lunch|for dinner)\b", "", text, flags=re.I)
    pieces = re.split(r"\n|,|;|\band\b|\bwith\b|\bplus\b|&", normalized)
    return [piece.strip(" .") for piece in pieces if piece.strip(" .")]


def _parse_food_fragment(fragment: str) -> ParsedFood:
    words = fragment.strip().split()
    quantity = 1.0
    unit = "serving"
    query = fragment
    start_index = 0

    if words:
        first_word = words[0].lower()
        if _looks_like_quantity(first_word):
            quantity = _quantity_from_text(first_word)
            start_index = 1
        elif first_word in {"a", "an"}:
            quantity = 1.0
            start_index = 1

    if start_index < len(words) and _looks_like_unit(words[start_index]):
        unit = words[start_index]
        start_index += 1

    if start_index < len(words) and words[start_index].lower() == "of":
        start_index += 1

    if start_index < len(words):
        query = " ".join(words[start_index:])
    return ParsedFood(query=_clean_food_query(query), quantity=quantity, unit=unit, raw_text=fragment)


def _looks_like_quantity(value: str) -> bool:
    return bool(
        re.match(
            r"^(\d+(?:\.\d+)?|\d+\s*/\s*\d+|one|two|three|four|five|six|seven|eight|nine|ten|half)$",
            value.lower().strip(),
        )
    )


def _quantity_from_text(value: str | None) -> float:
    if not value:
        return 1.0
    words = {
        "one": 1,
        "two": 2,
        "three": 3,
        "four": 4,
        "five": 5,
        "six": 6,
        "seven": 7,
        "eight": 8,
        "nine": 9,
        "ten": 10,
        "half": 0.5,
    }
    lowered = value.lower().strip()
    if lowered in words:
        return float(words[lowered])
    try:
        return float(Fraction(lowered.replace(" ", "")))
    except (ValueError, ZeroDivisionError):
        return 1.0


def _looks_like_unit(value: str) -> bool:
    return value.lower().strip() in {
        "cup",
        "cups",
        "piece",
        "pieces",
        "slice",
        "slices",
        "serving",
        "servings",
        "bowl",
        "bowls",
        "plate",
        "plates",
        "oz",
        "ounce",
        "ounces",
        "g",
        "gram",
        "grams",
        "lb",
        "pound",
        "pounds",
        "tbsp",
        "tablespoon",
        "tablespoons",
        "tsp",
        "teaspoon",
        "teaspoons",
    }


def _clean_food_query(value: str) -> str:
    cleaned = re.sub(r"\b(small|large|medium|of|some|about|around)\b", "", value, flags=re.I)
    return re.sub(r"\s+", " ", cleaned).strip(" .")


def _estimate_with_usda(foods: list[ParsedFood]) -> dict[str, Any] | None:
    totals = {"calories": 0.0, "carbohydrates": 0.0, "protein": 0.0, "fat": 0.0}
    matched_foods: list[str] = []
    missing: list[str] = []

    for food in foods:
        match = _search_usda_food(food.query)
        if not match:
            missing.append(food.query)
            continue
        grams = food.estimated_grams
        factor = grams / 100
        nutrients = _nutrients_per_100g(match)
        for key in totals:
            totals[key] += nutrients.get(key, 0.0) * factor
        matched_foods.append(f"{food.quantity:g} {food.unit} {match['description']} (FDC {match['fdcId']})")

    if not matched_foods:
        return None

    confidence = "medium" if not missing else "low"
    if len(matched_foods) >= 2 and not missing:
        confidence = "high"
    explanation = (
        "Estimated by matching parsed food items to USDA FoodData Central records "
        f"({', '.join(USDA_DATA_TYPES)}) and scaling nutrients by approximate portion weight."
    )
    if missing:
        explanation += f" No USDA match was found for: {', '.join(missing)}."

    return _format_result(
        calories=totals["calories"],
        carbohydrates=totals["carbohydrates"],
        protein=totals["protein"],
        fat=totals["fat"],
        matched_foods=matched_foods,
        source="usda_fdc",
        confidence=confidence,
        explanation=explanation,
    )


def _search_usda_food(query: str) -> dict[str, Any] | None:
    database_path = Path(os.getenv("USDA_OFFLINE_DB_PATH", str(USDA_OFFLINE_DB)))
    tokens = re.findall(r"[a-z0-9]+", _food_search_query(query).lower())[:8]
    LAST_NUTRITION_STATUS.update(offline_lookup_attempted=True, offline_lookup_ok=False, offline_lookup_last_error_type="request_started")
    if not tokens:
        LAST_NUTRITION_STATUS["offline_lookup_last_error_type"] = "invalid_query"
        return None
    try:
        with closing(sqlite3.connect(f"{database_path.resolve().as_uri()}?mode=ro", uri=True)) as database:
            database.row_factory = sqlite3.Row
            rows = database.execute(
                "SELECT f.fdc_id, f.description, f.data_type, f.calories, f.carbohydrates, f.protein, f.fat "
                "FROM foods_fts JOIN foods AS f ON f.fdc_id = foods_fts.rowid "
                "WHERE foods_fts MATCH ? ORDER BY bm25(foods_fts) LIMIT 100",
                (" OR ".join(tokens),),
            ).fetchall()
    except (OSError, sqlite3.Error) as exc:
        LAST_NUTRITION_STATUS["offline_lookup_last_error_type"] = type(exc).__name__
        logger.warning("Offline USDA lookup failed: %s", exc)
        return None
    foods = [
        {
            "fdcId": row["fdc_id"],
            "description": row["description"],
            "dataType": row["data_type"],
            "foodNutrients": [
                {"nutrientId": nutrient_id, "value": row[column]}
                for column, nutrient_id in NUTRIENT_IDS.items()
            ],
        }
        for row in rows
    ]
    if not foods:
        LAST_NUTRITION_STATUS["offline_lookup_last_error_type"] = "no_match"
        return None
    match = _best_usda_match(query, foods)
    LAST_NUTRITION_STATUS.update(
        offline_lookup_ok=match is not None,
        offline_lookup_last_error_type=None if match else "no_confident_match",
    )
    return match


def _food_search_query(query: str) -> str:
    lowered = query.lower().strip()
    canonical_queries = {
        "chicken": "chicken breast cooked",
        "rice": "rice cooked nfs",
        "apple": "apple raw",
        "banana": "banana raw",
        "egg": "egg cooked",
    }
    return canonical_queries.get(lowered, query)


def _best_usda_match(query: str, foods: list[dict[str, Any]]) -> dict[str, Any] | None:
    search_query = _food_search_query(query)
    query_tokens = _food_tokens(search_query)
    minimum_overlap = min(2, len(query_tokens))
    candidates = [
        food for food in foods
        if _nutrients_per_100g(food)["calories"] > 0
        and len(query_tokens & _food_tokens(str(food.get("description", "")))) >= minimum_overlap
    ]
    if not candidates:
        return None
    return max(candidates, key=lambda food: _usda_match_score(search_query, query_tokens, food))


def _usda_match_score(search_query: str, query_tokens: set[str], food: dict[str, Any]) -> float:
    description = str(food.get("description", "")).lower()
    description_tokens = _food_tokens(description)
    overlap = len(query_tokens & description_tokens)
    extra_tokens = len(description_tokens - query_tokens - {"nfs", "ns", "cooked", "raw"})
    score = overlap * 10 - extra_tokens * 0.6

    if description.startswith(search_query.lower()):
        score += 4
    if any(description.startswith(token) for token in query_tokens):
        score += 2
    if "raw" in query_tokens and "raw" in description_tokens:
        score += 3
    if "cooked" in query_tokens and "cooked" in description_tokens:
        score += 3
    score -= _mismatch_penalty(query_tokens, description_tokens)
    if food.get("dataType") == "Foundation":
        score += 2
    elif food.get("dataType") == "SR Legacy":
        score += 1
    return score


def _mismatch_penalty(query_tokens: set[str], description_tokens: set[str]) -> float:
    penalty = 0.0
    if "rice" in query_tokens and "noodles" in description_tokens:
        penalty += 12
    if "chicken" in query_tokens:
        penalty += 8 * len(
            (description_tokens - query_tokens)
            & {
                "breaded",
                "fried",
                "tenders",
                "roll",
                "feet",
                "skin",
                "back",
                "tail",
                "soup",
                "orange",
                "biryani",
                "almond",
            }
        )
    return penalty


def _food_tokens(value: str) -> set[str]:
    return {
        token
        for token in re.findall(r"[a-z]+", value.lower())
        if token not in {"and", "with", "without", "the", "a", "an", "of", "or"}
    }


def _nutrients_per_100g(food: dict[str, Any]) -> dict[str, float]:
    values = {key: 0.0 for key in NUTRIENT_IDS}
    for nutrient in food.get("foodNutrients", []):
        nutrient_id = nutrient.get("nutrientId")
        for key, expected_id in NUTRIENT_IDS.items():
            if nutrient_id == expected_id:
                values[key] = _safe_nonnegative_float(nutrient.get("value", 0))
    return values


def _estimated_grams(quantity: float, unit: str, query: str) -> float:
    normalized_unit = unit.lower().strip()
    query_lower = query.lower()
    rice_or_pasta = any(word in query_lower for word in ("rice", "pasta", "oat"))
    grams_per_unit = {
        "g": 1,
        "gram": 1,
        "grams": 1,
        "oz": 28.35,
        "ounce": 28.35,
        "ounces": 28.35,
        "lb": 453.59,
        "pound": 453.59,
        "pounds": 453.59,
        "cup": 160 if rice_or_pasta else 240,
        "cups": 160 if rice_or_pasta else 240,
        "slice": 30,
        "slices": 30,
        "piece": 100,
        "pieces": 100,
        "bowl": 300,
        "bowls": 300,
        "plate": 350,
        "plates": 350,
        "serving": 100,
        "servings": 100,
        "tbsp": 15,
        "tablespoon": 15,
        "tablespoons": 15,
        "tsp": 5,
        "teaspoon": 5,
        "teaspoons": 5,
    }
    grams = grams_per_unit.get(normalized_unit, 100) * quantity
    if "small" in query_lower:
        grams *= 0.75
    if "large" in query_lower:
        grams *= 1.25
    return max(5, min(grams, 2000))


def _dedupe_foods(foods: list[ParsedFood]) -> list[ParsedFood]:
    seen: set[tuple[str, str, float]] = set()
    deduped: list[ParsedFood] = []
    for food in foods:
        key = (food.query.lower(), food.unit.lower(), round(food.quantity, 2))
        if food.query and key not in seen:
            seen.add(key)
            deduped.append(food)
    return deduped


def _safe_nonnegative_float(value: Any) -> float:
    parsed = float(value)
    if parsed < 0:
        raise ValueError("Nutrition values must be nonnegative.")
    return parsed


def get_nutrition_ai_status() -> dict[str, Any]:
    return {
        "food_vision_model": MODEL_NAME,
        "food_vision_model_available": model_available(),
        "usda_offline_database_available": Path(os.getenv("USDA_OFFLINE_DB_PATH", str(USDA_OFFLINE_DB))).is_file(),
        "usda_fdc_data_types": list(USDA_DATA_TYPES),
        "nutrition_source": "USDA FoodData Central offline dataset",
        **LAST_NUTRITION_STATUS,
    }


def _format_result(
    *,
    calories: float,
    carbohydrates: float,
    protein: float,
    fat: float,
    matched_foods: list[str],
    source: str,
    confidence: str,
    explanation: str,
) -> dict[str, Any]:
    return {
        "calories": int(round(calories)),
        "carbohydrates": round(carbohydrates, 1),
        "protein": round(protein, 1),
        "fat": round(fat, 1),
        "matched_foods": matched_foods,
        "source": source,
        "confidence": confidence,
        "explanation": explanation,
        "disclaimer": DISCLAIMER,
    }


def validate_base64_images(images: list[str]) -> None:
    for image in images[:4]:
        try:
            base64.b64decode(image, validate=True)
        except ValueError as exc:
            raise ValueError("Images must be base64 encoded.") from exc
