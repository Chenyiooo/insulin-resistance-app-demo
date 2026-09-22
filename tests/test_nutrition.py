import io
import json
import unittest
from urllib.error import HTTPError, URLError
from unittest.mock import patch

from backend.nutrition import estimate_nutrition, get_nutrition_ai_status


class FakeResponse:
    def __init__(self, payload: dict):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def read(self):
        return json.dumps(self.payload).encode("utf-8")


class NutritionEstimatorTest(unittest.TestCase):
    def test_estimates_common_text_foods_without_network(self):
        with patch("backend.nutrition.urllib.request.urlopen", side_effect=AssertionError("network used")):
            result = estimate_nutrition(text="I ate chicken, rice, and an apple.")

        self.assertGreater(result["calories"], 300)
        self.assertGreater(result["carbohydrates"], 40)
        self.assertGreater(result["protein"], 20)
        self.assertEqual(result["source"], "usda_fdc")
        self.assertTrue(any("Chicken" in food and "fried" not in food for food in result["matched_foods"]))
        self.assertTrue(get_nutrition_ai_status()["usda_offline_database_available"])

    def test_photo_without_model_does_not_invent_nutrition(self):
        with patch.dict("os.environ", {"OPENAI_API_KEY": ""}):
            result = estimate_nutrition(text="", image_base64=["Zm9vZA=="])

        self.assertEqual(result["source"], "unable_to_estimate")
        self.assertEqual(result["confidence"], "low")
        self.assertEqual(result["calories"], 0)
        self.assertIn("Describe the food", result["explanation"])

    def test_openai_failure_still_uses_offline_database_for_text(self):
        with patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"}):
            with patch("backend.nutrition.urllib.request.urlopen", side_effect=URLError("offline")):
                result = estimate_nutrition(text="I ate chicken and rice.", image_base64=["Zm9vZA=="])

        self.assertEqual(result["source"], "usda_fdc")
        self.assertTrue(any("Chicken" in food for food in result["matched_foods"]))

    def test_openai_identifies_photo_foods_but_offline_database_calculates_nutrients(self):
        response = FakeResponse({"output_text": json.dumps({"ingredient_lines": ["1 cup cooked rice", "1 serving chicken"]})})
        with patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"}):
            with patch("backend.nutrition.urllib.request.urlopen", return_value=response) as urlopen:
                result = estimate_nutrition(text="", image_base64=["Zm9vZA=="])

        self.assertEqual(urlopen.call_count, 1)
        self.assertIn("api.openai.com", urlopen.call_args.args[0].full_url)
        self.assertEqual(result["source"], "usda_fdc")
        self.assertGreater(result["calories"], 250)
        self.assertTrue(any("Rice" in food for food in result["matched_foods"]))

    def test_credit_exhaustion_is_diagnosed_without_fake_photo_values(self):
        body = io.BytesIO(json.dumps({"error": {"code": "credit_balance_exhausted"}}).encode())
        error = HTTPError("https://api.openai.com/v1/responses", 429, "Too Many Requests", {}, body)
        with patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"}):
            with patch("backend.nutrition.urllib.request.urlopen", side_effect=error):
                result = estimate_nutrition(text="", image_base64=["Zm9vZA=="])

        self.assertEqual(result["source"], "unable_to_estimate")
        self.assertEqual(result["calories"], 0)
        self.assertEqual(get_nutrition_ai_status()["openai_last_error_code"], "credit_balance_exhausted")

    def test_missing_offline_database_fails_closed(self):
        with patch.dict("os.environ", {"USDA_OFFLINE_DB_PATH": "/no/such/usda.sqlite"}):
            result = estimate_nutrition(text="1 apple")

        self.assertEqual(result["source"], "unable_to_estimate")
        self.assertEqual(result["calories"], 0)


if __name__ == "__main__":
    unittest.main()
