import json
import unittest
from urllib.error import URLError
from unittest.mock import patch

from backend.nutrition import estimate_nutrition


class FakeResponse:
    def __init__(self, payload: dict):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def read(self):
        return json.dumps(self.payload).encode("utf-8")


def fake_fdc_response(query: str) -> FakeResponse:
    foods = {
        "chicken_bad": {
            "fdcId": 171514,
            "description": "Chicken breast tenders, breaded, cooked, microwaved",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 252},
                {"nutrientId": 1005, "value": 16},
                {"nutrientId": 1003, "value": 16},
                {"nutrientId": 1004, "value": 13},
            ],
        },
        "chicken": {
            "fdcId": 171077,
            "description": "Chicken breast, cooked",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 165},
                {"nutrientId": 1005, "value": 0},
                {"nutrientId": 1003, "value": 31},
                {"nutrientId": 1004, "value": 3.6},
            ],
        },
        "rice_bad": {
            "fdcId": 168914,
            "description": "Rice noodles, cooked",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 108},
                {"nutrientId": 1005, "value": 24},
                {"nutrientId": 1003, "value": 1.8},
                {"nutrientId": 1004, "value": 0.2},
            ],
        },
        "rice": {
            "fdcId": 168878,
            "description": "Rice, white, cooked",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 130},
                {"nutrientId": 1005, "value": 28},
                {"nutrientId": 1003, "value": 2.7},
                {"nutrientId": 1004, "value": 0.3},
            ],
        },
        "apple": {
            "fdcId": 171688,
            "description": "Apples, raw",
            "foodNutrients": [
                {"nutrientId": 1008, "value": 52},
                {"nutrientId": 1005, "value": 13.8},
                {"nutrientId": 1003, "value": 0.3},
                {"nutrientId": 1004, "value": 0.2},
            ],
        },
    }
    query_lower = query.lower()
    matches = []
    if "chicken" in query_lower:
        matches.extend([foods["chicken_bad"], foods["chicken"]])
    if "rice" in query_lower:
        matches.extend([foods["rice_bad"], foods["rice"]])
    if "apple" in query_lower:
        matches.append(foods["apple"])
    return FakeResponse({"foods": matches})


def fdc_urlopen(request, timeout=12):
    body = json.loads(request.data.decode("utf-8"))
    return fake_fdc_response(body["query"])


class NutritionEstimatorTest(unittest.TestCase):
    def test_estimates_common_text_foods_from_usda(self):
        with patch("backend.nutrition.urllib.request.urlopen", side_effect=fdc_urlopen):
            result = estimate_nutrition(text="I ate chicken, rice, and an apple.")

        self.assertGreater(result["calories"], 300)
        self.assertGreater(result["carbohydrates"], 40)
        self.assertGreater(result["protein"], 20)
        self.assertEqual(result["source"], "usda_fdc")
        self.assertIn("USDA FoodData Central", result["explanation"])
        self.assertTrue(any("Chicken breast" in food for food in result["matched_foods"]))

    def test_photo_without_model_does_not_invent_generic_nutrition(self):
        result = estimate_nutrition(text="", image_base64=["Zm9vZA=="])

        self.assertEqual(result["source"], "unable_to_estimate")
        self.assertEqual(result["confidence"], "low")
        self.assertEqual(result["calories"], 0)

    def test_openai_failure_still_uses_usda_for_text(self):
        def urlopen(request, timeout=12):
            if "openai.com" in request.full_url:
                raise URLError("offline")
            return fdc_urlopen(request, timeout=timeout)

        with patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"}, clear=False):
            with patch("backend.nutrition.urllib.request.urlopen", side_effect=urlopen):
                result = estimate_nutrition(
                    text="I ate chicken and rice.",
                    image_base64=["Zm9vZA=="],
                )

        self.assertEqual(result["source"], "usda_fdc")
        self.assertTrue(any("Chicken breast" in food for food in result["matched_foods"]))
        self.assertIn("not medical or dietary advice", result["disclaimer"])

    def test_openai_identifies_photo_foods_but_usda_calculates_nutrients(self):
        def urlopen(request, timeout=12):
            if "openai.com" in request.full_url:
                return FakeResponse(
                    {
                        "output_text": json.dumps(
                            {"ingredient_lines": ["1 cup cooked rice", "1 serving chicken"]}
                        )
                    }
                )
            return fdc_urlopen(request, timeout=timeout)

        with patch.dict(
            "os.environ",
            {"OPENAI_API_KEY": "test-key", "OPENAI_NUTRITION_MODEL": "gpt-5-mini"},
            clear=False,
        ):
            with patch("backend.nutrition.urllib.request.urlopen", side_effect=urlopen):
                result = estimate_nutrition(
                    text="",
                    image_base64=["Zm9vZA=="],
                )

        self.assertEqual(result["source"], "usda_fdc")
        self.assertGreater(result["calories"], 250)
        self.assertTrue(any("Rice, white" in food for food in result["matched_foods"]))
        self.assertIn("USDA FoodData Central", result["disclaimer"])


if __name__ == "__main__":
    unittest.main()
