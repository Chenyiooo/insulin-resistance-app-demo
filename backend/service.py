from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd

from backend.config import settings
from src.lifestyle_suggestions import generate_lifestyle_suggestions


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FEATURES_PATH = REPO_ROOT / "data" / "processed" / "features_used.txt"

OPTIONAL_MODEL_FEATURES = {"systolic_bp", "diastolic_bp", "pulse"}


@dataclass(frozen=True)
class PredictionResult:
    model_name: str
    model_version: str
    probability: float
    percent: int
    band: str
    threshold: float
    features_used: list[str]
    imputed_features: list[str]
    increasing_factors: list[str]
    decreasing_factors: list[str]
    suggestions: list[dict[str, Any]]
    disclaimer: str


class ModelInputError(ValueError):
    """Raised when a request cannot be converted to model-ready input."""

    def __init__(self, message: str, missing_features: list[str] | None = None):
        super().__init__(message)
        self.missing_features = missing_features or []


class RiskPredictionService:
    def __init__(self, model_path: Path | None = None):
        model_path = model_path or settings.model_path
        self.model_path = model_path
        if not model_path.exists():
            raise FileNotFoundError(
                f"Model bundle not found at {model_path}. Run 08_train_reduced_lightgbm.py first."
            )

        bundle = joblib.load(model_path)
        self.model = bundle["model"]
        self.imputer = bundle["imputer"]
        self.features = list(bundle["features"])
        self.profile_inputs = list(bundle.get("profile_inputs", []))
        self.checkin_inputs = list(bundle.get("checkin_inputs", []))
        self.metrics = dict(bundle.get("metrics", {}))
        self.model_name = "reduced_lightgbm"
        self.model_version = "low_burden_18_feature_v1"
        self.threshold = 0.5

    def schema(self) -> dict[str, Any]:
        return {
            "model_name": self.model_name,
            "model_version": self.model_version,
            "features": self.features,
            "profile_inputs": self.profile_inputs,
            "checkin_inputs": self.checkin_inputs,
            "derived_inputs": ["bmi", "waist_height_ratio"],
            "optional_inputs": sorted(OPTIONAL_MODEL_FEATURES.intersection(self.features)),
            "metrics": self.metrics,
            "units": {
                "height": "cm",
                "weight": "kg",
                "waist_circumference": "cm",
                "systolic_bp": "mmHg",
                "diastolic_bp": "mmHg",
                "sleep_hours": "hours",
            },
        }

    def predict(
        self,
        payload: dict[str, Any],
        recent_checkins: list[dict[str, Any]] | None = None,
    ) -> PredictionResult:
        features = self._extract_features(payload)
        row, imputed_features = self._build_feature_row(features)
        probability = float(self.model.predict_proba(row)[:, 1][0])
        percent = int(round(probability * 100))
        band = self._risk_band(probability)
        factors = self._factor_summary(features)
        suggestions = self._suggestions(features, recent_checkins)

        return PredictionResult(
            model_name=self.model_name,
            model_version=self.model_version,
            probability=probability,
            percent=percent,
            band=band,
            threshold=self.threshold,
            features_used=self.features,
            imputed_features=imputed_features,
            increasing_factors=factors["increasing"],
            decreasing_factors=factors["decreasing"],
            suggestions=suggestions,
            disclaimer=(
                "This is a screening estimate for reflection and wellness support, "
                "not a medical diagnosis or medical advice."
            ),
        )

    def _extract_features(self, payload: dict[str, Any]) -> dict[str, Any]:
        merged: dict[str, Any] = {}
        for section in ("profileInputs", "checkInInputs", "derivedInputs", "profile_inputs", "checkin_inputs", "derived_inputs"):
            value = payload.get(section)
            if isinstance(value, dict):
                merged.update(value)

        features = payload.get("features")
        if isinstance(features, dict):
            merged.update(features)

        if not merged:
            merged = {
                key: value
                for key, value in payload.items()
                if key in self.features
            }

        return merged

    def _build_feature_row(self, features: dict[str, Any]) -> tuple[np.ndarray, list[str]]:
        missing_required = [
            feature
            for feature in self.features
            if feature not in features and feature not in OPTIONAL_MODEL_FEATURES
        ]
        if missing_required:
            raise ModelInputError(
                f"Missing required model inputs: {missing_required}",
                missing_features=missing_required,
            )

        values: dict[str, float] = {}
        imputed_features: list[str] = []
        for feature in self.features:
            raw_value = features.get(feature, np.nan)
            if raw_value is None or raw_value == "":
                raw_value = np.nan
            try:
                value = float(raw_value)
            except (TypeError, ValueError):
                value = np.nan

            if np.isnan(value):
                imputed_features.append(feature)
            values[feature] = value

        frame = pd.DataFrame([values], columns=self.features)
        return self.imputer.transform(frame), imputed_features

    def _risk_band(self, probability: float) -> str:
        if probability >= 0.5:
            return "High Risk"
        if probability >= 0.25:
            return "Moderate Risk"
        return "Lower Risk"

    def _factor_summary(self, features: dict[str, Any]) -> dict[str, list[str]]:
        increasing: list[str] = []
        decreasing: list[str] = []

        age = _num(features.get("age"))
        if age is not None:
            if age >= 45:
                increasing.append("Age 45 or older")
            elif age < 35:
                decreasing.append("Younger age")

        bmi = _num(features.get("bmi"))
        if bmi is not None:
            if bmi >= 30:
                increasing.append("BMI in the obesity range")
            elif bmi >= 25:
                increasing.append("BMI in the overweight range")
            elif bmi >= 18.5:
                decreasing.append("BMI in the typical range")

        waist = _num(features.get("waist_circumference"))
        sex = _num(features.get("sex"))
        if waist is not None:
            high_waist = waist >= 102 if sex == 1 else waist >= 88
            if high_waist:
                increasing.append("Higher waist circumference")
            elif waist > 0:
                decreasing.append("Waist circumference in a lower range")

        systolic = _num(features.get("systolic_bp"))
        diastolic = _num(features.get("diastolic_bp"))
        if systolic is not None and diastolic is not None:
            if systolic >= 140 or diastolic >= 90:
                increasing.append("Recent blood pressure in a high range")
            elif systolic < 120 and diastolic < 80:
                decreasing.append("Recent blood pressure in a lower range")

        flag_labels = [
            ("family_diabetes", "Close family history of diabetes"),
            ("hypertension_history", "History of high blood pressure"),
            ("hypertension_med", "Blood pressure medication use"),
            ("high_cholesterol", "History of high cholesterol"),
            ("gestational_diabetes", "History of gestational diabetes"),
        ]
        for feature, label in flag_labels:
            if _num(features.get(feature)) == 1:
                increasing.append(label)

        smoking = _num(features.get("smoking_status"))
        if smoking == 2:
            increasing.append("Current smoking")
        elif smoking == 0:
            decreasing.append("No smoking history reported")

        sleep = _num(features.get("sleep_hours"))
        if sleep is not None:
            if sleep < 6:
                increasing.append("Short sleep duration")
            elif 7 <= sleep <= 9:
                decreasing.append("Typical sleep duration")

        return {
            "increasing": _unique(increasing)[:5] or ["No major increasing factors from submitted data"],
            "decreasing": _unique(decreasing)[:5] or ["No major decreasing factors from submitted data"],
        }

    def _suggestions(
        self,
        features: dict[str, Any],
        recent_checkins: list[dict[str, Any]] | None,
    ) -> list[dict[str, Any]]:
        checkins = recent_checkins or [
            {
                "sleep_hours": features.get("sleep_hours"),
                "alcohol_frequency": features.get("alcohol_frequency"),
            }
        ]
        suggestions = generate_lifestyle_suggestions(
            checkins=checkins,
            profile={"alcohol_frequency": features.get("alcohol_frequency")},
            max_suggestions=3,
        )
        return [
            {
                "domain": suggestion.domain.value,
                "title": suggestion.title,
                "text": suggestion.suggestion_text,
                "trigger_reason": suggestion.trigger_reason,
                "safety_note": suggestion.safety_note,
                "confidence": suggestion.confidence,
            }
            for suggestion in suggestions
        ]


def prediction_to_dict(result: PredictionResult) -> dict[str, Any]:
    return asdict(result)


def _num(value: Any) -> float | None:
    try:
        if value is None or value == "":
            return None
        number = float(value)
        if np.isnan(number):
            return None
        return number
    except (TypeError, ValueError):
        return None


def _unique(values: list[str]) -> list[str]:
    seen: set[str] = set()
    unique_values: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            unique_values.append(value)
    return unique_values
