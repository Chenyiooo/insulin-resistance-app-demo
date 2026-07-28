"""Train only the active reduced LightGBM model."""
import json
import os

import joblib
import numpy as np
import pandas as pd
from lightgbm import LGBMClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    average_precision_score,
    brier_score_loss,
    confusion_matrix,
    f1_score,
    roc_auc_score,
)

from config import (
    BINARY_TARGET,
    DATA_PROCESSED_DIR,
    MODELS_DIR,
    PREDICTOR_FEATURES,
    PROFILE_INPUT_FEATURES,
    DAILY_INPUT_FEATURES,
    RANDOM_STATE,
    RESULTS_DIR,
)


PARAMS = {
    "n_estimators": 500,
    "max_depth": 4,
    "learning_rate": 0.01,
    "num_leaves": 63,
    "subsample": 1.0,
    "is_unbalance": True,
    "random_state": RANDOM_STATE,
    "verbose": -1,
    "n_jobs": -1,
}


def expected_calibration_error(y_true, y_prob, n_bins=10):
    bins = np.linspace(0, 1, n_bins + 1)
    ids = np.clip(np.digitize(y_prob, bins) - 1, 0, n_bins - 1)
    value = 0.0
    for idx in range(n_bins):
        mask = ids == idx
        if mask.any():
            value += mask.mean() * abs(y_true[mask].mean() - y_prob[mask].mean())
    return float(value)


def calibration_slope_intercept(y_true, y_prob):
    eps = 1e-6
    clipped = np.clip(y_prob, eps, 1 - eps)
    logits = np.log(clipped / (1 - clipped)).reshape(-1, 1)
    lr = LogisticRegression(penalty=None, solver="lbfgs", max_iter=1000)
    lr.fit(logits, y_true)
    return float(lr.coef_[0][0]), float(lr.intercept_[0])


def metrics(y_true, y_prob):
    y_pred = (y_prob >= 0.5).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
    slope, intercept = calibration_slope_intercept(y_true, y_prob)
    return {
        "auc": roc_auc_score(y_true, y_prob),
        "auprc": average_precision_score(y_true, y_prob),
        "sensitivity": tp / (tp + fn),
        "specificity": tn / (tn + fp),
        "f1": f1_score(y_true, y_pred),
        "fnr": fn / (tp + fn),
        "brier": brier_score_loss(y_true, y_prob),
        "ece_10bin": expected_calibration_error(y_true, y_prob),
        "calibration_slope": slope,
        "calibration_intercept": intercept,
    }


def main():
    os.makedirs(MODELS_DIR, exist_ok=True)
    out_dir = os.path.join(RESULTS_DIR, "reduced_lightgbm")
    os.makedirs(out_dir, exist_ok=True)

    train = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "train.parquet"))
    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    features = [f for f in PREDICTOR_FEATURES if f in train.columns and f in test.columns]

    imputer = SimpleImputer(strategy="median")
    x_train = imputer.fit_transform(train[features])
    x_test = imputer.transform(test[features])
    y_train = train[BINARY_TARGET].values
    y_test = test[BINARY_TARGET].values

    model = LGBMClassifier(**PARAMS)
    model.fit(x_train, y_train)
    y_prob = model.predict_proba(x_test)[:, 1]
    result = metrics(y_test, y_prob)

    bundle = {
        "model": model,
        "imputer": imputer,
        "features": features,
        "profile_inputs": PROFILE_INPUT_FEATURES,
        "checkin_inputs": DAILY_INPUT_FEATURES,
        "metrics": result,
        "params": PARAMS,
    }
    joblib.dump(bundle, os.path.join(MODELS_DIR, "reduced_lightgbm_bundle.joblib"))
    pd.DataFrame([{ "model": "reduced_lightgbm", "n_features": len(features), **result }]).to_csv(
        os.path.join(out_dir, "reduced_lightgbm_performance.csv"), index=False
    )
    with open(os.path.join(out_dir, "reduced_lightgbm_performance.json"), "w") as f:
        json.dump({"n_features": len(features), "features": features, **result}, f, indent=2)

    print(f"Features ({len(features)}): {features}")
    print(json.dumps(result, indent=2))
    print(f"Saved: {os.path.join(MODELS_DIR, 'reduced_lightgbm_bundle.joblib')}")


if __name__ == "__main__":
    main()
