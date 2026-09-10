from __future__ import annotations

import base64
import json
import logging
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from fractions import Fraction
from typing import Any


logger = logging.getLogger(__name__)

DISCLAIMER = (
    "Nutrition values are estimates for reflection only, not medical or dietary advice. "
    "Values are calculated from USDA FoodData Central matches when available; accuracy "
    "depends on food identification, portion size, recipe, and preparation method."
)

USDA_FDC_SEARCH_URL = "https://api.nal.usda.gov/fdc/v1/foods/search"
USDA_DATA_TYPES = ("Survey (FNDDS)", "Foundation", "SR Legacy")
NUTRIENT_IDS = {
    "calories": 1008,
    "protein": 1003,
    "fat": 1004,
    "carbohydrates": 1005,
}

LAST_NUTRITION_STATUS: dict[str, Any] = {
    "openai_attempted": False,
    "openai_ok": False,
    "openai_last_error_type": "not_attempted",
    "openai_last_http_status": None,
    "usda_attempted": False,
    "usda_ok": False,
    "usda_last_error_type": "not_attempted",
    "usda_last_http_status": None,
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
        parsed_foods.extend(_identify_foods_with_openai(text=text, image_base64=images))

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
            "Food items were detected, but USDA FoodData Central could not be reached "
            "or did not return usable nutrient matches."
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


def _identify_foods_with_openai(text: str, image_base64: list[str]) -> list[ParsedFood]:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        _record_openai_status(ok=False, error_type="not_configured")
        return []

    content: list[dict[str, Any]] = [
        {
            "type": "input_text",
            "text": (
                "Identify foods and approximate portions from this food photo/text input. "
                "Do not estimate calories or nutrients. Return only JSON with an "
                "ingredient_lines array, where each item is a short ingredient phrase such as "
                "'1 cup cooked rice' or '1 medium apple'. "
                f"Typed description: {text or '(none)'}"
            ),
        }
    ]
    for encoded in image_base64[:4]:
        content.append(
            {
                "type": "input_image",
                "image_url": f"data:image/jpeg;base64,{encoded}",
                "detail": os.getenv("OPENAI_NUTRITION_IMAGE_DETAIL", "high"),
            }
        )

    payload = {
        "model": os.getenv("OPENAI_NUTRITION_MODEL", "gpt-4o-mini"),
        "input": [{"role": "user", "content": content}],
    }
    request = urllib.request.Request(
        "https://api.openai.com/v1/responses",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    _record_openai_status(ok=False, error_type="request_started")
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:500]
        _record_openai_status(ok=False, error_type="http_error", http_status=exc.code)
        logger.warning("OpenAI food identification failed status=%s body=%s", exc.code, body)
        return []
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        _record_openai_status(ok=False, error_type=type(exc).__name__)
        logger.warning("OpenAI food identification failed: %s", exc)
        return []

    text_output = _extract_openai_text(raw)
    parsed = _json_object_from_text(text_output)
    if not parsed:
        _record_openai_status(ok=False, error_type="invalid_output_json")
        return []

    ingredient_lines = parsed.get("ingredient_lines", [])
    if not isinstance(ingredient_lines, list):
        _record_openai_status(ok=False, error_type="invalid_ingredient_lines")
        return []

    _record_openai_status(ok=True, error_type=None)
    return _parse_food_text("\n".join(str(item) for item in ingredient_lines))


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
    api_key = os.getenv("USDA_FDC_API_KEY", "DEMO_KEY")
    params = urllib.parse.urlencode({"api_key": api_key})
    payload = {
        "query": _food_search_query(query),
        "pageSize": 25,
        "dataType": list(USDA_DATA_TYPES),
    }
    request = urllib.request.Request(
        f"{USDA_FDC_SEARCH_URL}?{params}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    _record_usda_status(ok=False, error_type="request_started")
    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            raw = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        _record_usda_status(ok=False, error_type="http_error", http_status=exc.code)
        logger.warning("USDA FoodData Central request failed status=%s query=%s", exc.code, query)
        return None
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        _record_usda_status(ok=False, error_type=type(exc).__name__)
        logger.warning("USDA FoodData Central request failed query=%s error=%s", query, exc)
        return None

    foods = raw.get("foods", [])
    if not foods:
        _record_usda_status(ok=False, error_type="no_match")
        return None
    _record_usda_status(ok=True, error_type=None)
    return _best_usda_match(query, foods)


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
    candidates = [food for food in foods if _nutrients_per_100g(food)["calories"] > 0]
    if not candidates:
        return None
    search_query = _food_search_query(query)
    query_tokens = _food_tokens(search_query)
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
            description_tokens
            & {
                "breaded",
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


def _record_openai_status(*, ok: bool, error_type: str | None, http_status: int | None = None) -> None:
    LAST_NUTRITION_STATUS.update(
        {
            "openai_attempted": error_type != "not_configured",
            "openai_ok": ok,
            "openai_last_error_type": error_type,
            "openai_last_http_status": http_status,
        }
    )


def _record_usda_status(*, ok: bool, error_type: str | None, http_status: int | None = None) -> None:
    LAST_NUTRITION_STATUS.update(
        {
            "usda_attempted": error_type != "not_configured",
            "usda_ok": ok,
            "usda_last_error_type": error_type,
            "usda_last_http_status": http_status,
        }
    )


def get_nutrition_ai_status() -> dict[str, Any]:
    return {
        "openai_api_key_configured": bool(os.getenv("OPENAI_API_KEY")),
        "openai_model": os.getenv("OPENAI_NUTRITION_MODEL", "gpt-4o-mini"),
        "openai_image_detail": os.getenv("OPENAI_NUTRITION_IMAGE_DETAIL", "high"),
        "usda_fdc_api_key_configured": bool(os.getenv("USDA_FDC_API_KEY")),
        "usda_fdc_data_types": list(USDA_DATA_TYPES),
        "nutrition_source": "USDA FoodData Central",
        **LAST_NUTRITION_STATUS,
    }


def _extract_openai_text(response: dict[str, Any]) -> str:
    if isinstance(response.get("output_text"), str):
        return response["output_text"]
    parts: list[str] = []
    for item in response.get("output", []):
        for content in item.get("content", []):
            text = content.get("text")
            if isinstance(text, str):
                parts.append(text)
    return "\n".join(parts)


def _json_object_from_text(text: str) -> dict[str, Any] | None:
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", text, flags=re.DOTALL)
        if not match:
            return None
        try:
            parsed = json.loads(match.group(0))
        except json.JSONDecodeError:
            return None
    return parsed if isinstance(parsed, dict) else None


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
