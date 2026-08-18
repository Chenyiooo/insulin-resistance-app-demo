import unittest
from urllib.error import URLError
from unittest.mock import patch

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

    def test_openai_failure_falls_back_to_local_rules(self):
        with patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"}, clear=False):
            with patch("backend.nutrition.urllib.request.urlopen", side_effect=URLError("offline")):
                result = estimate_nutrition(
                    text="I ate chicken and rice.",
                    image_base64=["Zm9vZA=="],
                )

        self.assertEqual(result["source"], "local_rules")
        self.assertIn("chicken", result["matched_foods"])
        self.assertIn("not medical or dietary advice", result["disclaimer"])

    def test_openai_mixed_text_and_image_response_is_used(self):
        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, traceback):
                return False

            def read(self):
                return b'''
                {
                  "output_text": "{\\"calories\\": 520, \\"carbohydrates\\": 58, \\"protein\\": 31, \\"fat\\": 17, \\"matched_foods\\": [\\"rice bowl\\"], \\"confidence\\": \\"medium\\", \\"explanation\\": \\"Estimated from the food photo and description.\\"}"
                }
                '''

        with patch.dict(
            "os.environ",
            {"OPENAI_API_KEY": "test-key", "OPENAI_NUTRITION_MODEL": "gpt-5-mini"},
            clear=False,
        ):
            with patch("backend.nutrition.urllib.request.urlopen", return_value=FakeResponse()):
                result = estimate_nutrition(
                    text="rice bowl with chicken",
                    image_base64=["Zm9vZA=="],
                )

        self.assertEqual(result["source"], "vision_language_model")
        self.assertEqual(result["calories"], 520)
        self.assertEqual(result["matched_foods"], ["rice bowl"])
        self.assertIn("not medical or dietary advice", result["disclaimer"])


if __name__ == "__main__":
    unittest.main()
