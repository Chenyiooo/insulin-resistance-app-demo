import ast
import re
from pathlib import Path

from fastapi import HTTPException

from backend import main
from backend.service import ModelInputError
from tests.test_backend_service import complete_features


REPO_ROOT = Path(__file__).resolve().parents[1]
IOS_MAPPER = REPO_ROOT / "ios-app" / "Sources" / "InsulinResistanceApp" / "ModelInputMapper.swift"


def test_backend_schema_matches_ios_mapper_feature_contract():
    schema = main.service.schema()
    ios_predictor_features = _swift_string_array("predictorFeatures")
    ios_optional_features = _swift_string_array("optionalInputFeatures")

    assert schema["features"] == ios_predictor_features
    assert schema["optional_inputs"] == sorted(ios_optional_features)
    assert len(schema["features"]) == 18


def test_predict_endpoint_accepts_ios_payload_shape_and_returns_safe_output():
    features = complete_features()
    request = main.PredictRequest(
        modelName="reduced_lightgbm",
        modelVersion="low_burden_18_feature_v1",
        featureOrder=main.service.features,
        features=features,
        profileInputs={
            key: features[key]
            for key in ("age", "sex", "race", "height", "family_diabetes")
        },
        checkInInputs={
            key: features[key]
            for key in ("weight", "waist_circumference", "sleep_hours")
        },
        derivedInputs={
            "bmi": features["bmi"],
            "waist_height_ratio": features["waist_height_ratio"],
        },
    )

    response = main.predict(request)

    assert 0 <= response["probability"] <= 1
    assert 0 <= response["percent"] <= 100
    assert response["features_used"] == main.service.features
    assert response["band"] in {"Lower Risk", "Moderate Risk", "High Risk"}
    assert "not a medical diagnosis" in response["disclaimer"]


def test_predict_endpoint_rejects_app_reported_missing_required_inputs():
    request = main.PredictRequest(
        features=complete_features(),
        missingRequiredInputs=[
            main.MissingDataItemRequest(field="waist_circumference", label="Waist circumference")
        ],
    )

    try:
        main.predict(request)
    except HTTPException as exc:
        assert exc.status_code == 422
        assert exc.detail["missing_features"] == ["waist_circumference"]
        assert "missing required inputs" in exc.detail["message"]
    else:
        raise AssertionError("Expected missing required input to be rejected.")


def test_predict_endpoint_rejects_mismatched_feature_order():
    wrong_order = list(main.service.features)
    wrong_order[0], wrong_order[1] = wrong_order[1], wrong_order[0]
    request = main.PredictRequest(
        modelName="reduced_lightgbm",
        modelVersion="low_burden_18_feature_v1",
        featureOrder=wrong_order,
        features=complete_features(),
    )

    try:
        main.predict(request)
    except HTTPException as exc:
        assert exc.status_code == 422
        assert "feature order" in exc.detail["message"]
        assert exc.detail["expected_features"] == main.service.features
    else:
        raise AssertionError("Expected mismatched feature order to be rejected.")


def test_predict_endpoint_rejects_mismatched_model_version():
    request = main.PredictRequest(
        modelName="reduced_lightgbm",
        modelVersion="wrong_version",
        featureOrder=main.service.features,
        features=complete_features(),
    )

    try:
        main.predict(request)
    except HTTPException as exc:
        assert exc.status_code == 422
        assert "model version" in exc.detail["message"]
        assert exc.detail["expected"] == "low_burden_18_feature_v1"
    else:
        raise AssertionError("Expected mismatched model version to be rejected.")


def test_predict_endpoint_rejects_invalid_required_numeric_values():
    features = complete_features()
    features["weight"] = ""

    try:
        main.service.predict({"features": features})
    except ModelInputError as exc:
        assert exc.missing_features == ["weight"]
        assert "invalid required model inputs" in str(exc)
    else:
        raise AssertionError("Expected invalid required model input to be rejected.")


def _swift_string_array(name: str) -> list[str]:
    source = IOS_MAPPER.read_text()
    match = re.search(rf"static let {name} = \[(.*?)\]", source, flags=re.S)
    if not match:
        raise AssertionError(f"Could not find Swift array {name}.")
    return ast.literal_eval("[" + match.group(1) + "]")
