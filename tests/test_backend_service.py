import unittest

from backend.service import ModelInputError, RiskPredictionService


class RiskPredictionServiceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.service = RiskPredictionService()

    def test_predicts_with_complete_feature_payload(self):
        result = self.service.predict({"features": complete_features()})

        self.assertGreaterEqual(result.probability, 0)
        self.assertLessEqual(result.probability, 1)
        self.assertEqual(len(result.features_used), 18)
        self.assertEqual(result.imputed_features, [])
        self.assertTrue(result.disclaimer)

    def test_omitted_optional_blood_pressure_is_imputed(self):
        features = complete_features()
        features.pop("systolic_bp")
        features.pop("diastolic_bp")

        result = self.service.predict({"features": features})

        self.assertIn("systolic_bp", result.imputed_features)
        self.assertIn("diastolic_bp", result.imputed_features)

    def test_missing_required_feature_raises_input_error(self):
        with self.assertRaises(ModelInputError) as context:
            self.service.predict({"features": {"age": 34}})

        self.assertIn("sex", context.exception.missing_features)
        self.assertIn("waist_height_ratio", context.exception.missing_features)


def complete_features():
    return {
        "age": 34,
        "sex": 2,
        "race": 5,
        "bmi": 23.9,
        "waist_circumference": 83.8,
        "weight": 67.1,
        "height": 167.6,
        "systolic_bp": 122,
        "diastolic_bp": 78,
        "family_diabetes": 1,
        "hypertension_history": 0,
        "hypertension_med": 0,
        "high_cholesterol": 0,
        "smoking_status": 0,
        "alcohol_frequency": 0,
        "sleep_hours": 7,
        "gestational_diabetes": 0,
        "waist_height_ratio": 0.50,
    }


if __name__ == "__main__":
    unittest.main()
