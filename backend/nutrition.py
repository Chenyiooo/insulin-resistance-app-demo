from __future__ import annotations

import base64
import json
import os
import re
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


DISCLAIMER = (
    "Nutrition values are estimates for reflection only. Accuracy depends on food "
    "identification, portion size, recipe, and preparation method."
)


@dataclass(frozen=True)
class FoodProfile:
    calories: float
    carbohydrates: float
    protein: float
    fat: float
    aliases: tuple[str, ...]


FOODS: dict[str, FoodProfile] = {
    "rice": FoodProfile(205, 45, 4, 0.4, ("rice", "white rice", "brown rice")),
    "chicken": FoodProfile(165, 0, 31, 3.6, ("chicken", "chicken breast")),
    "egg": FoodProfile(72, 0.4, 6.3, 4.8, ("egg", "eggs")),
    "bread": FoodProfile(80, 15, 3, 1, ("bread", "toast")),
    "oatmeal": FoodProfile(154, 27, 6, 3, ("oatmeal", "oats")),
    "banana": FoodProfile(105, 27, 1.3, 0.4, ("banana",)),
    "apple": FoodProfile(95, 25, 0.5, 0.3, ("apple",)),
    "salad": FoodProfile(120, 12, 4, 7, ("salad",)),
    "pasta": FoodProfile(220, 43, 8, 1.3, ("pasta", "spaghetti", "noodles")),
    "beef": FoodProfile(250, 0, 26, 15, ("beef", "steak")),
    "pork": FoodProfile(240, 0, 25, 14, ("pork",)),
    "fish": FoodProfile(180, 0, 25, 8, ("fish", "salmon", "tuna")),
    "tofu": FoodProfile(145, 4, 16, 9, ("tofu",)),
    "beans": FoodProfile(225, 40, 15, 1, ("beans", "black beans", "lentils")),
    "potato": FoodProfile(160, 37, 4, 0.2, ("potato", "potatoes")),
    "yogurt": FoodProfile(150, 17, 9, 4, ("yogurt",)),
    "milk": FoodProfile(122, 12, 8, 5, ("milk",)),
    "avocado": FoodProfile(240, 13, 3, 22, ("avocado",)),
    "pizza": FoodProfile(285, 36, 12, 10, ("pizza",)),
    "burger": FoodProfile(540, 40, 25, 30, ("burger", "hamburger")),
    "fries": FoodProfile(365, 48, 4, 17, ("fries", "french fries")),
    "soda": FoodProfile(150, 39, 0, 0, ("soda", "cola")),
}


COUNT_WORDS = {
    "a": 1,
    "an": 1,
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
}


def estimate_nutrition(text: str = "", image_base64: list[str] | None = None) -> dict[str, Any]:
    images = image_base64 or []
    ai_result = _estimate_with_openai(text=text, image_base64=images)
    if ai_result:
        return ai_result

    local = _estimate_from_text(text)
    if local["matched_foods"]:
        return local

    if images:
        servings = max(1, min(len(images), 4))
        return _format_result(
            calories=450 * servings,
            carbohydrates=48 * servings,
            protein=22 * servings,
            fat=16 * servings,
            matched_foods=["photo meal estimate"],
            source="photo_fallback",
            confidence="low",
            explanation=(
                "Photo upload was received, but no vision model is configured on the "
                "backend. This uses a conservative generic meal estimate until the "
                "photo can be identified by a model."
            ),
        )

    return _format_result(
        calories=0,
        carbohydrates=0,
        protein=0,
        fat=0,
        matched_foods=[],
        source="local_rules",
        confidence="low",
        explanation="No recognizable foods were found. Add foods or portions for a better estimate.",
    )


def _estimate_from_text(text: str) -> dict[str, Any]:
    normalized = text.lower()
    calories = carbohydrates = protein = fat = 0.0
    matched: list[str] = []

    for name, profile in FOODS.items():
        if not any(re.search(rf"\b{re.escape(alias)}\b", normalized) for alias in profile.aliases):
            continue
        multiplier = _portion_multiplier(normalized, profile.aliases)
        calories += profile.calories * multiplier
        carbohydrates += profile.carbohydrates * multiplier
        protein += profile.protein * multiplier
        fat += profile.fat * multiplier
        matched.append(name if multiplier == 1 else f"{multiplier:g}x {name}")

    confidence = "medium" if len(matched) >= 2 else "low"
    explanation = (
        "Estimated from the typed food description using common serving-size nutrition values."
        if matched
        else "No recognizable foods were found in the typed description."
    )
    return _format_result(
        calories=calories,
        carbohydrates=carbohydrates,
        protein=protein,
        fat=fat,
        matched_foods=matched,
        source="local_rules",
        confidence=confidence,
        explanation=explanation,
    )


def _portion_multiplier(text: str, aliases: tuple[str, ...]) -> float:
    multiplier = 1.0
    for alias in aliases:
        pattern = rf"(?:(\d+(?:\.\d+)?)|({'|'.join(COUNT_WORDS)}))\s+(?:cups?|pieces?|servings?|plates?|bowls?|slices?)?\s*{re.escape(alias)}"
        match = re.search(pattern, text)
        if match:
            if match.group(1):
                multiplier = float(match.group(1))
            elif match.group(2):
                multiplier = float(COUNT_WORDS[match.group(2)])
            break
    if "small" in text:
        multiplier *= 0.75
    if "large" in text:
        multiplier *= 1.25
    if "half" in text:
        multiplier *= 0.5
    return max(0.25, min(multiplier, 6))


def _estimate_with_openai(text: str, image_base64: list[str]) -> dict[str, Any] | None:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None

    content: list[dict[str, Any]] = [
        {
            "type": "input_text",
            "text": (
                "Estimate calories and macronutrients for this food intake. "
                "Use photos and text together. Return only JSON with keys: "
                "calories, carbohydrates, protein, fat, matched_foods, confidence, explanation. "
                "Use grams for macros. If uncertain, be conservative and explain uncertainty. "
                f"Typed description: {text or '(none)'}"
            ),
        }
    ]
    for encoded in image_base64[:4]:
        content.append(
            {
                "type": "input_image",
                "image_url": f"data:image/jpeg;base64,{encoded}",
            }
        )

    payload = {
        "model": os.getenv("OPENAI_NUTRITION_MODEL", "gpt-5"),
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
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
        return None

    text_output = _extract_openai_text(raw)
    if not text_output:
        return None
    try:
        parsed = json.loads(text_output)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", text_output, flags=re.DOTALL)
        if not match:
            return None
        parsed = json.loads(match.group(0))

    return _format_result(
        calories=float(parsed.get("calories", 0)),
        carbohydrates=float(parsed.get("carbohydrates", 0)),
        protein=float(parsed.get("protein", 0)),
        fat=float(parsed.get("fat", 0)),
        matched_foods=[str(item) for item in parsed.get("matched_foods", [])],
        source="vision_language_model",
        confidence=str(parsed.get("confidence", "medium")),
        explanation=str(parsed.get("explanation", "Estimated from food photo/text input.")),
    )


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
