"""Focused LightGBM validation for the compact significant-input model.

This script avoids the all-model workflow. It retrains LightGBM variants on the
same train/test split and writes validation tables plus a Markdown report.
"""
import json
import os
from collections import Counter

import joblib
import numpy as np
import pandas as pd
from lightgbm import LGBMClassifier
from sklearn.calibration import calibration_curve
from sklearn.impute import SimpleImputer
from sklearn.metrics import (
    average_precision_score,
    brier_score_loss,
    confusion_matrix,
    f1_score,
    roc_auc_score,
)
from sklearn.model_selection import StratifiedKFold

from config import (
    BINARY_TARGET,
    DATA_PROCESSED_DIR,
    MODELS_DIR,
    RANDOM_STATE,
    RESULTS_DIR,
    TABLES_DIR,
)


ORIGINAL_FEATURES = [
    "age", "sex", "race", "education", "income_ratio",
    "bmi", "waist_circumference", "weight", "height",
    "systolic_bp", "diastolic_bp", "pulse",
    "family_diabetes", "hypertension_history", "hypertension_med", "high_cholesterol",
    "smoking_status",
    "alcohol_frequency", "alcohol_avg_drinks",
    "vigorous_work", "moderate_work", "vigorous_recreation", "moderate_recreation",
    "sedentary_minutes",
    "sleep_hours", "sleep_trouble",
    "phq9_score",
    "gestational_diabetes",
    "weight_change_pct",
    "waist_height_ratio",
    "diet_recall_days",
    "diet_energy_kcal_avg",
    "diet_protein_g_avg",
    "diet_carb_g_avg",
    "diet_sugar_g_avg",
    "diet_fiber_g_avg",
    "diet_total_fat_g_avg",
    "diet_sat_fat_g_avg",
    "diet_mono_fat_g_avg",
    "diet_poly_fat_g_avg",
    "diet_cholesterol_mg_avg",
    "diet_sodium_mg_avg",
    "diet_potassium_mg_avg",
    "diet_calcium_mg_avg",
    "diet_magnesium_mg_avg",
    "diet_vitamin_d_mcg_avg",
    "diet_caffeine_mg_avg",
    "diet_alcohol_g_avg",
    "supplement_used",
    "supplement_count",
    "antacid_used",
    "antacid_count",
    "supp_energy_kcal",
    "supp_protein_g",
    "supp_carb_g",
    "supp_sugar_g",
    "supp_fiber_g",
    "supp_total_fat_g",
    "supp_sat_fat_g",
    "supp_mono_fat_g",
    "supp_poly_fat_g",
    "supp_cholesterol_mg",
    "supp_sodium_mg",
    "supp_potassium_mg",
    "supp_calcium_mg",
    "supp_magnesium_mg",
    "supp_vitamin_d_mcg",
    "supp_caffeine_mg",
]

COMPACT_FEATURES = [
    "age",
    "race",
    "bmi",
    "waist_circumference",
    "hypertension_history",
    "high_cholesterol",
    "alcohol_frequency",
    "weight_change_pct",
    "waist_height_ratio",
    "diet_caffeine_mg_avg",
    "diet_alcohol_g_avg",
]

LGBM_PARAMS = {
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
    bins = np.linspace(0.0, 1.0, n_bins + 1)
    ids = np.digitize(y_prob, bins) - 1
    ids = np.clip(ids, 0, n_bins - 1)
    ece = 0.0
    for bin_id in range(n_bins):
        mask = ids == bin_id
        if not mask.any():
            continue
        ece += mask.mean() * abs(y_true[mask].mean() - y_prob[mask].mean())
    return float(ece)


def calibration_slope_intercept(y_true, y_prob):
    from sklearn.linear_model import LogisticRegression

    eps = 1e-6
    clipped = np.clip(y_prob, eps, 1 - eps)
    logits = np.log(clipped / (1 - clipped)).reshape(-1, 1)
    lr = LogisticRegression(penalty=None, solver="lbfgs", max_iter=1000)
    lr.fit(logits, y_true)
    return float(lr.coef_[0][0]), float(lr.intercept_[0])


def metrics(y_true, y_prob, threshold=0.5):
    y_pred = (y_prob >= threshold).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
    slope, intercept = calibration_slope_intercept(y_true, y_prob)
    return {
        "auc": roc_auc_score(y_true, y_prob),
        "auprc": average_precision_score(y_true, y_prob),
        "sensitivity": tp / (tp + fn) if tp + fn else np.nan,
        "specificity": tn / (tn + fp) if tn + fp else np.nan,
        "f1": f1_score(y_true, y_pred),
        "false_negative_rate": fn / (tp + fn) if tp + fn else np.nan,
        "brier": brier_score_loss(y_true, y_prob),
        "ece_10bin": expected_calibration_error(y_true, y_prob),
        "calibration_slope": slope,
        "calibration_intercept": intercept,
    }


def fit_predict(train, test, features, feature_overrides=None):
    features = [f for f in features if f in train.columns and f in test.columns]
    X_train = train[features].copy()
    X_test = test[features].copy()
    if feature_overrides:
        for feature, values in feature_overrides.items():
            if feature in X_test.columns:
                X_test[feature] = values

    imputer = SimpleImputer(strategy="median")
    X_train_i = imputer.fit_transform(X_train)
    X_test_i = imputer.transform(X_test)

    model = LGBMClassifier(**LGBM_PARAMS)
    model.fit(X_train_i, train[BINARY_TARGET].values)
    y_prob = model.predict_proba(X_test_i)[:, 1]
    return model, imputer, features, y_prob


def cv_train_only_feature_selection(train, original_features, k=11):
    features = [f for f in original_features if f in train.columns]
    y = train[BINARY_TARGET].values
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)
    gains = Counter()
    selected_by_fold = []

    for fold, (tr_idx, val_idx) in enumerate(skf.split(train[features], y), start=1):
        X_tr = train.iloc[tr_idx][features]
        y_tr = y[tr_idx]
        imputer = SimpleImputer(strategy="median")
        X_tr_i = imputer.fit_transform(X_tr)
        model = LGBMClassifier(**LGBM_PARAMS)
        model.fit(X_tr_i, y_tr)
        fold_gain = model.booster_.feature_importance(importance_type="gain")
        ranked = sorted(zip(features, fold_gain), key=lambda x: x[1], reverse=True)
        selected = [feature for feature, _ in ranked[:k]]
        selected_by_fold.append({"fold": fold, "features": selected})
        for feature, gain in ranked:
            gains[feature] += float(gain)

    ranked_avg = [
        {"feature": feature, "mean_gain": gain / skf.get_n_splits()}
        for feature, gain in gains.most_common()
    ]
    selected = [row["feature"] for row in ranked_avg[:k]]
    return selected, ranked_avg, selected_by_fold


def subgroup_metrics(test, y_prob, model_name):
    rows = []
    subgroup_defs = {
        "sex": {
            "Male": test["sex"] == 1,
            "Female": test["sex"] == 2,
        },
        "race": {
            "Hispanic": test["race"].isin([1, 2]),
            "NH White": test["race"] == 3,
            "NH Black": test["race"] == 4,
            "Other": test["race"] == 5,
        },
    }
    y = test[BINARY_TARGET].values
    for group, labels in subgroup_defs.items():
        for label, mask in labels.items():
            mask = np.asarray(mask)
            if mask.sum() < 20 or len(np.unique(y[mask])) < 2:
                continue
            vals = metrics(y[mask], y_prob[mask])
            rows.append({
                "model": model_name,
                "group": group,
                "subgroup": label,
                "n": int(mask.sum()),
                "prevalence": float(y[mask].mean()),
                **vals,
            })
    return rows


def write_report(path, perf, subgroup, cv_selected, diet_rows, robustness_rows, redundancy_rows):
    best_compact = perf.loc[perf["model"] == "compact_11"].iloc[0]
    original = perf.loc[perf["model"] == "original_67"].iloc[0]
    no_race = perf.loc[perf["model"] == "compact_no_race"].iloc[0]

    lines = [
        "# LightGBM Compact Model Validation",
        "",
        "This validation retrains LightGBM only. All comparisons use the same train/test split.",
        "",
        "## Main Comparison",
        "",
        perf.to_markdown(index=False, floatfmt=".4f"),
        "",
        "## Key Findings",
        "",
        f"- Original 67-feature LightGBM AUC: {original['auc']:.4f}.",
        f"- Compact 11-feature LightGBM AUC: {best_compact['auc']:.4f}.",
        f"- Compact model AUPRC: {best_compact['auprc']:.4f}; F1: {best_compact['f1']:.4f}.",
        f"- Removing race changed AUC from {best_compact['auc']:.4f} to {no_race['auc']:.4f} and false-negative rate from {best_compact['false_negative_rate']:.4f} to {no_race['false_negative_rate']:.4f}.",
        "",
        "## Train-Only Feature Selection Leakage Check",
        "",
        "Feature selection was re-run using only the training split with 5-fold CV LightGBM gain importance. The held-out test split was not used for this selection check.",
        "",
        "Top 11 train-CV selected features:",
        "",
        ", ".join(f"`{f}`" for f in cv_selected),
        "",
        "The proposed compact feature set should be treated as a product candidate, not as a final locked clinical feature set, unless it matches the train-only selection criterion or is frozen before external validation.",
        "",
        "## Race And Sex Subgroup Metrics",
        "",
        subgroup.to_markdown(index=False, floatfmt=".4f"),
        "",
        "## Weight History Robustness",
        "",
        robustness_rows.to_markdown(index=False, floatfmt=".4f"),
        "",
        "## Diet Record Duration",
        "",
        "NHANES provides up to two 24-hour dietary recall days, so this dataset can directly validate one-day versus two-day averages only. Three-day and seven-day reliability require prospective app data or another dataset with longer food logs.",
        "",
        diet_rows.to_markdown(index=False, floatfmt=".4f"),
        "",
        "## Alcohol Redundancy",
        "",
        redundancy_rows.to_markdown(index=False, floatfmt=".4f"),
        "",
        "## Product Input Frequency Recommendation",
        "",
        "- Profile information: entered once and updated when demographics or clinical history changes.",
        "- Weight: weekly is enough for risk tracking; daily entry may create unnecessary burden.",
        "- Waist circumference: monthly is a better fit because measurement error is high and changes slowly.",
        "- Alcohol and caffeine: optional behavioral records used to calculate longer-term averages. The app should avoid requiring daily diet logging for core screening.",
        "",
        "## Calibration Definitions",
        "",
        "- Brier score: lower is better.",
        "- ECE 10-bin: expected calibration error across 10 probability bins; lower is better.",
        "- Calibration slope near 1 and intercept near 0 indicate better calibration.",
    ]
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    os.makedirs(TABLES_DIR, exist_ok=True)
    validation_dir = os.path.join(RESULTS_DIR, "validation")
    os.makedirs(validation_dir, exist_ok=True)

    train = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "train.parquet"))
    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    y_test = test[BINARY_TARGET].values

    original_features = [f for f in ORIGINAL_FEATURES if f in train.columns and f in test.columns]
    compact_features = [f for f in COMPACT_FEATURES if f in train.columns and f in test.columns]

    variants = {
        "original_67": original_features,
        "compact_11": compact_features,
        "compact_no_race": [f for f in compact_features if f != "race"],
        "compact_no_weight_change": [f for f in compact_features if f != "weight_change_pct"],
        "compact_no_alcohol": [
            f for f in compact_features
            if f not in ("alcohol_frequency", "diet_alcohol_g_avg")
        ],
        "compact_no_caffeine": [f for f in compact_features if f != "diet_caffeine_mg_avg"],
        "compact_alcohol_frequency_only": [
            f for f in compact_features if f != "diet_alcohol_g_avg"
        ],
        "compact_diet_alcohol_only": [
            f for f in compact_features if f != "alcohol_frequency"
        ],
    }

    predictions = {}
    perf_rows = []
    fitted = {}
    for name, features in variants.items():
        model, imputer, used_features, y_prob = fit_predict(train, test, features)
        fitted[name] = {"model": model, "imputer": imputer, "features": used_features}
        predictions[name] = y_prob
        perf_rows.append({
            "model": name,
            "n_features": len(used_features),
            **metrics(y_test, y_prob),
        })

    cv_selected, cv_ranked, selected_by_fold = cv_train_only_feature_selection(
        train, original_features, k=11
    )
    model, imputer, used_features, y_prob = fit_predict(train, test, cv_selected)
    predictions["train_cv_selected_11"] = y_prob
    perf_rows.append({
        "model": "train_cv_selected_11",
        "n_features": len(used_features),
        **metrics(y_test, y_prob),
    })

    # Weight history robustness.
    median_wc = train["weight_change_pct"].median()
    robustness = []
    overrides = {
        "missing_weight_10yr": pd.Series(median_wc, index=test.index),
    }
    if {"weight", "weight_10yr_ago"}.issubset(test.columns):
        base = test["weight_10yr_ago"].copy()
        for label, factor in {
            "weight_10yr_underestimated_10pct": 0.90,
            "weight_10yr_overestimated_10pct": 1.10,
            "weight_10yr_underestimated_20pct": 0.80,
            "weight_10yr_overestimated_20pct": 1.20,
        }.items():
            perturbed = base * factor
            valid = (perturbed > 20) & test["weight"].notna()
            vals = test["weight_change_pct"].copy()
            vals.loc[valid] = (test.loc[valid, "weight"] - perturbed.loc[valid]) / perturbed.loc[valid] * 100
            vals = vals.fillna(median_wc)
            overrides[label] = vals

    for label, values in overrides.items():
        _, _, _, y_prob = fit_predict(
            train,
            test,
            compact_features,
            feature_overrides={"weight_change_pct": values},
        )
        robustness.append({
            "scenario": label,
            **metrics(y_test, y_prob),
        })

    # Diet record duration variants available in NHANES: Day 1, Day 2, and 2-day average.
    diet_rows = []
    diet_scenarios = {
        "two_day_average_current": {},
    }
    if {"diet_day1_alcohol_g", "diet_day1_caffeine_mg"}.issubset(test.columns):
        diet_scenarios["day1_only"] = {
            "diet_alcohol_g_avg": test["diet_day1_alcohol_g"],
            "diet_caffeine_mg_avg": test["diet_day1_caffeine_mg"],
        }
    if {"diet_day2_alcohol_g", "diet_day2_caffeine_mg"}.issubset(test.columns):
        diet_scenarios["day2_only"] = {
            "diet_alcohol_g_avg": test["diet_day2_alcohol_g"],
            "diet_caffeine_mg_avg": test["diet_day2_caffeine_mg"],
        }
    diet_scenarios["no_diet_average_inputs"] = {
        "diet_alcohol_g_avg": pd.Series(train["diet_alcohol_g_avg"].median(), index=test.index),
        "diet_caffeine_mg_avg": pd.Series(train["diet_caffeine_mg_avg"].median(), index=test.index),
    }
    for label, override in diet_scenarios.items():
        _, _, _, y_prob = fit_predict(train, test, compact_features, feature_overrides=override)
        diet_rows.append({"scenario": label, **metrics(y_test, y_prob)})

    redundancy_rows = pd.DataFrame([
        row for row in perf_rows
        if row["model"] in (
            "compact_11",
            "compact_no_alcohol",
            "compact_alcohol_frequency_only",
            "compact_diet_alcohol_only",
        )
    ])

    subgroup_rows = []
    for name in ("compact_11", "compact_no_race"):
        subgroup_rows.extend(subgroup_metrics(test, predictions[name], name))

    perf = pd.DataFrame(perf_rows)
    subgroup = pd.DataFrame(subgroup_rows)
    diet_df = pd.DataFrame(diet_rows)
    robustness_df = pd.DataFrame(robustness)
    cv_ranked_df = pd.DataFrame(cv_ranked)
    selected_by_fold_df = pd.DataFrame(selected_by_fold)

    perf.to_csv(os.path.join(validation_dir, "lightgbm_validation_performance.csv"), index=False)
    subgroup.to_csv(os.path.join(validation_dir, "lightgbm_subgroup_metrics.csv"), index=False)
    diet_df.to_csv(os.path.join(validation_dir, "diet_record_duration.csv"), index=False)
    robustness_df.to_csv(os.path.join(validation_dir, "weight_history_robustness.csv"), index=False)
    redundancy_rows.to_csv(os.path.join(validation_dir, "alcohol_redundancy.csv"), index=False)
    cv_ranked_df.to_csv(os.path.join(validation_dir, "train_cv_feature_ranking.csv"), index=False)
    selected_by_fold_df.to_csv(os.path.join(validation_dir, "train_cv_selected_by_fold.csv"), index=False)

    # Save the focused compact LightGBM model separately from the all-model workflow.
    joblib.dump(
        {
            "model": fitted["compact_11"]["model"],
            "imputer": fitted["compact_11"]["imputer"],
            "features": fitted["compact_11"]["features"],
            "profile_inputs": [
                "age", "race", "height", "hypertension_history",
                "high_cholesterol", "weight_10yr_ago",
            ],
            "checkin_inputs": [
                "weight", "waist_circumference", "alcohol_frequency",
                "diet_alcohol_g_avg", "diet_caffeine_mg_avg",
            ],
        },
        os.path.join(MODELS_DIR, "compact_lightgbm_validation_bundle.joblib"),
    )

    report_path = os.path.join(validation_dir, "lightgbm_compact_validation_report.md")
    write_report(report_path, perf, subgroup, cv_selected, diet_df, robustness_df, redundancy_rows)
    print(f"Saved validation report: {report_path}")
    print(perf[["model", "n_features", "auc", "auprc", "sensitivity", "specificity", "f1", "brier", "ece_10bin"]])


if __name__ == "__main__":
    main()
