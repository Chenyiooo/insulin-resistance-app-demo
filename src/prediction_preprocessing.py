"""Utilities for preparing user-entered feature data for prediction."""
import os

import joblib
import numpy as np
import pandas as pd

from config import (
    DAILY_INPUT_FEATURES,
    MODELS_DIR,
    OPTIONAL_USER_INPUT_FEATURES,
    PROFILE_INPUT_FEATURES,
)

PREPROCESSOR_PATH = os.path.join(MODELS_DIR, "preprocessor.joblib")


def load_preprocessor(path=PREPROCESSOR_PATH):
    """Load the fitted preprocessing artifact saved by 02_build_dataset.py."""
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"Preprocessor not found at {path}. Run 02_build_dataset.py first."
        )
    return joblib.load(path)


def _numeric_fill_values(preprocessor):
    """Return training numeric fill values from old or new preprocessor artifacts."""
    if "numeric_fill_values" in preprocessor:
        return preprocessor["numeric_fill_values"]

    imputer = preprocessor.get("imputer")
    if imputer is None or not hasattr(imputer, "initial_imputer_"):
        return {}

    return {
        feature: fill_value
        for feature, fill_value in zip(
            preprocessor.get("numeric_features", []),
            imputer.initial_imputer_.statistics_,
        )
    }


def prepare_user_features(user_input, preprocessor=None, model_features=None):
    """Return an imputed feature matrix for model prediction.

    `user_input` may be a dict for one person or a DataFrame for many people.
    Blood pressure fields listed in OPTIONAL_USER_INPUT_FEATURES may be omitted;
    they are inserted as missing values and imputed with the training-fitted
    imputer or training fill values. Other model features remain required.

    Pass `model_features` when preparing inputs for a smaller model bundle.
    """
    if preprocessor is None:
        preprocessor = load_preprocessor()

    if isinstance(user_input, dict):
        X = pd.DataFrame([user_input])
    else:
        X = user_input.copy()

    preprocessor_features = preprocessor["features"]
    features = list(model_features) if model_features is not None else preprocessor_features
    optional_features = set(
        preprocessor.get("optional_features", OPTIONAL_USER_INPUT_FEATURES)
    )
    omitted_required = [
        feature
        for feature in features
        if feature not in X.columns and feature not in optional_features
    ]
    if omitted_required:
        raise ValueError(
            "Missing required model inputs: "
            f"{sorted(omitted_required)}. Optional inputs are: "
            f"{sorted(optional_features)}"
        )

    missing_optional = [feature for feature in optional_features if feature not in X.columns]
    for feature in missing_optional:
        X[feature] = np.nan

    X = X.reindex(columns=features)

    numeric_features = preprocessor.get("numeric_features", [])
    target_numeric_features = [f for f in numeric_features if f in features]
    for feature in target_numeric_features:
        if feature in X.columns:
            X[feature] = pd.to_numeric(X[feature], errors="coerce")

    for feature, fill_value in preprocessor.get("categorical_fill_values", {}).items():
        if feature in X.columns:
            X[feature] = X[feature].fillna(fill_value)

    imputer = preprocessor.get("imputer")
    if features == preprocessor_features and imputer is not None and numeric_features:
        X.loc[:, numeric_features] = imputer.transform(X[numeric_features])
    else:
        fill_values = _numeric_fill_values(preprocessor)
        for feature in target_numeric_features:
            if feature in fill_values:
                X[feature] = X[feature].fillna(fill_values[feature])

    return X


def prepare_checkin_features(profile_input, daily_input, preprocessor=None, model_features=None):
    """Prepare model features from profile-once and daily check-in inputs."""
    user_input = {**profile_input, **daily_input}

    missing_profile = [f for f in PROFILE_INPUT_FEATURES if f not in profile_input]
    missing_daily = [f for f in DAILY_INPUT_FEATURES if f not in daily_input]
    if missing_profile or missing_daily:
        raise ValueError(
            "Missing profile inputs: "
            f"{sorted(missing_profile)}; missing daily inputs: {sorted(missing_daily)}"
        )

    height = pd.to_numeric(pd.Series([user_input["height"]]), errors="coerce").iloc[0]
    weight = pd.to_numeric(pd.Series([user_input["weight"]]), errors="coerce").iloc[0]
    waist = pd.to_numeric(
        pd.Series([user_input["waist_circumference"]]), errors="coerce"
    ).iloc[0]
    weight_10yr_ago = pd.to_numeric(
        pd.Series([user_input["weight_10yr_ago"]]), errors="coerce"
    ).iloc[0]

    if pd.notna(height) and height > 0 and pd.notna(weight):
        user_input["bmi"] = weight / ((height / 100) ** 2)

    if pd.notna(height) and height > 0 and pd.notna(waist):
        user_input["waist_height_ratio"] = waist / height

    if pd.notna(weight_10yr_ago) and weight_10yr_ago > 20 and pd.notna(weight):
        user_input["weight_change_pct"] = (
            (weight - weight_10yr_ago) / weight_10yr_ago * 100
        )

    return prepare_user_features(user_input, preprocessor, model_features)
