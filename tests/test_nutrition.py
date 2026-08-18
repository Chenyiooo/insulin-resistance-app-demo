import unittest

from backend.nutrition import estimate_nutrition


class NutritionEstimatorTest(unittest.TestCase):
    def test_estimates_common_text_foods(self):
        result = estimate_nutrition(text="I ate chicken, rice, and an apple.")

        self.assertGreater(result["calories"], 300)
        self.assertGreater(result["carbohydrates"], 40)
        self.assertGreater(result["protein"], 20)
        self.assertEqual(result["source"], "local_rules")
        self.assertIn("chicken", result["matched_foods"])

    def test_photo_without_model_returns_low_confidence_fallback(self):
        result = estimate_nutrition(text="", image_base64=["Zm9vZA=="])

        self.assertEqual(result["source"], "photo_fallback")
        self.assertEqual(result["confidence"], "low")
        self.assertGreater(result["calories"], 0)


if __name__ == "__main__":
    unittest.main()
