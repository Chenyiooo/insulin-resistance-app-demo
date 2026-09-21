import unittest
from unittest.mock import patch

from backend.nutrition import estimate_nutrition, get_nutrition_ai_status


class NutritionEstimatorTest(unittest.TestCase):
    def test_text_uses_bundled_usda_data_without_network(self):
        with patch("urllib.request.urlopen", side_effect=AssertionError("network used")):
            result = estimate_nutrition(text="1 cup cooked rice and 1 medium apple")

        self.assertEqual(result["source"], "usda_fdc")
        self.assertGreater(result["calories"], 200)
        self.assertGreater(result["carbohydrates"], 40)
        self.assertTrue(any("Rice, cooked" in food for food in result["matched_foods"]))
        self.assertTrue(get_nutrition_ai_status()["usda_offline_database_available"])

    def test_unknown_food_is_not_mapped_to_unrelated_nutrition(self):
        result = estimate_nutrition(text="mysterious unknown food")
        self.assertEqual(result["source"], "unable_to_estimate")
        self.assertEqual(result["calories"], 0)

    def test_photo_without_model_does_not_invent_nutrition(self):
        with patch("backend.nutrition.model_available", return_value=False):
            result = estimate_nutrition(image_base64=["Zm9vZA=="])
        self.assertEqual(result["source"], "unable_to_estimate")
        self.assertEqual(result["confidence"], "low")

    def test_photo_model_weight_scales_offline_usda_macros(self):
        with patch("backend.nutrition.model_available", return_value=True):
            with patch("backend.nutrition.recognize_foods", return_value=[("Apple", 150)]):
                result = estimate_nutrition(image_base64=["Zm9vZA=="])

        self.assertEqual(result["source"], "usda_fdc")
        self.assertEqual(result["calories"], 92)
        self.assertGreater(result["carbohydrates"], 20)
        self.assertGreater(result["protein"], 0)
        self.assertGreater(result["fat"], 0)
        self.assertEqual(result["confidence"], "low")

    def test_photo_model_failure_fails_closed(self):
        with patch("backend.nutrition.model_available", return_value=True):
            with patch("backend.nutrition.recognize_foods", side_effect=ValueError("bad image")):
                with patch("backend.nutrition.logger.exception"):
                    result = estimate_nutrition(image_base64=["Zm9vZA=="])
        self.assertEqual(result["source"], "unable_to_estimate")
        self.assertEqual(get_nutrition_ai_status()["food_vision_last_error_type"], "ValueError")

    def test_missing_database_fails_closed(self):
        with patch.dict("os.environ", {"USDA_OFFLINE_DB_PATH": "/tmp/nonexistent-usda-foods.sqlite"}):
            with patch("backend.nutrition.logger.warning"):
                result = estimate_nutrition(text="1 apple")
        self.assertEqual(result["source"], "unable_to_estimate")


if __name__ == "__main__":
    unittest.main()
