import base64
import io
import unittest
from unittest.mock import Mock, patch

import numpy as np
from PIL import Image

from backend.food_vision import recognize_foods


def sample_image() -> str:
    output = io.BytesIO()
    Image.new("RGB", (2, 2), "white").save(output, format="PNG")
    return base64.b64encode(output.getvalue()).decode()


class FoodVisionTests(unittest.TestCase):
    def test_unrecognized_food_does_not_load_portion_model(self):
        classifier = Mock()
        classifier.run.return_value = [np.array([[-20.0]], dtype=np.float32)]
        with patch("backend.food_vision._load_classifier", return_value=(["Apple"], classifier)):
            with patch("backend.food_vision._load_regressor") as load_regressor:
                self.assertEqual(recognize_foods([sample_image()]), [])
        load_regressor.assert_not_called()

    def test_recognized_food_uses_predicted_grams(self):
        classifier = Mock()
        classifier.run.return_value = [np.array([[20.0]], dtype=np.float32)]
        regressor = Mock()
        regressor.run.return_value = [np.array([[150.0]], dtype=np.float32)]
        with patch("backend.food_vision._load_classifier", return_value=(["Apple"], classifier)):
            with patch("backend.food_vision._load_regressor", return_value=regressor):
                self.assertEqual(recognize_foods([sample_image()]), [("Apple", 150.0)])


if __name__ == "__main__":
    unittest.main()
