"""LightGBM-only input reduction from the restored 67-feature baseline."""
import os

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

from config import BINARY_TARGET, DATA_PROCESSED_DIR, RANDOM_STATE, RESULTS_DIR


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

DIET_AVG = [
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
]

SUPPLEMENTS = [
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

ACTIVITY_SLEEP_MOOD = [
    "vigorous_work",
    "moderate_work",
    "vigorous_recreation",
    "moderate_recreation",
    "sedentary_minutes",
    "sleep_hours",
    "sleep_trouble",
    "phq9_score",
]

BP = ["systolic_bp", "diastolic_bp"]
ALCOHOL = ["alcohol_frequency", "alcohol_avg_drinks", "diet_alcohol_g_avg"]
WEIGHT_HISTORY = ["weight_change_pct"]
RACE = ["race"]
SOCIOECONOMIC = ["education", "income_ratio"]

CLINICAL_SCREEN = [
    "age", "sex", "race", "education", "income_ratio",
    "bmi", "waist_circumference", "weight", "height",
    "systolic_bp", "diastolic_bp",
    "family_diabetes", "hypertension_history", "hypertension_med",
    "high_cholesterol", "smoking_status",
    "alcohol_frequency", "alcohol_avg_drinks",
    "vigorous_work", "moderate_work", "vigorous_recreation",
    "moderate_recreation", "sedentary_minutes",
    "sleep_hours", "sleep_trouble", "phq9_score",
    "gestational_diabetes", "weight_change_pct", "waist_height_ratio",
]

LOW_BURDEN_SCREEN = [
    "age", "sex", "race",
    "bmi", "waist_circumference", "weight", "height",
    "systolic_bp", "diastolic_bp",
    "family_diabetes", "hypertension_history", "hypertension_med",
    "high_cholesterol", "smoking_status",
    "alcohol_frequency", "sleep_hours", "gestational_diabetes",
    "waist_height_ratio",
]

LOW_BURDEN_NO_BP = [f for f in LOW_BURDEN_SCREEN if f not in BP]


def ece(y_true, y_prob, n_bins=10):
    bins = np.linspace(0, 1, n_bins + 1)
    ids = np.clip(np.digitize(y_prob, bins) - 1, 0, n_bins - 1)
    val = 0.0
    for i in range(n_bins):
        mask = ids == i
        if mask.any():
            val += mask.mean() * abs(y_true[mask].mean() - y_prob[mask].mean())
    return float(val)


def calibration(y_true, y_prob):
    eps = 1e-6
    logits = np.log(np.clip(y_prob, eps, 1 - eps) / np.clip(1 - y_prob, eps, 1))
    lr = LogisticRegression(penalty=None, solver="lbfgs", max_iter=1000)
    lr.fit(logits.reshape(-1, 1), y_true)
    return float(lr.coef_[0][0]), float(lr.intercept_[0])


def calc_metrics(y_true, y_prob):
    y_pred = (y_prob >= 0.5).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
    slope, intercept = calibration(y_true, y_prob)
    return {
        "auc": roc_auc_score(y_true, y_prob),
        "auprc": average_precision_score(y_true, y_prob),
        "sensitivity": tp / (tp + fn),
        "specificity": tn / (tn + fp),
        "f1": f1_score(y_true, y_pred),
        "fnr": fn / (tp + fn),
        "brier": brier_score_loss(y_true, y_prob),
        "ece_10bin": ece(y_true, y_prob),
        "calibration_slope": slope,
        "calibration_intercept": intercept,
    }


def bootstrap_ci(y_true, y_prob, n_boot=300):
    rng = np.random.default_rng(RANDOM_STATE)
    rows = []
    n = len(y_true)
    for _ in range(n_boot):
        idx = rng.integers(0, n, n)
        if len(np.unique(y_true[idx])) < 2:
            continue
        rows.append(calc_metrics(y_true[idx], y_prob[idx]))
    boot = pd.DataFrame(rows)
    cis = {}
    for metric in ["auc", "auprc", "fnr", "brier", "ece_10bin"]:
        cis[f"{metric}_ci_low"] = boot[metric].quantile(0.025)
        cis[f"{metric}_ci_high"] = boot[metric].quantile(0.975)
    return cis


def fit_predict(train, test, features):
    features = [f for f in features if f in train.columns and f in test.columns]
    imputer = SimpleImputer(strategy="median")
    x_train = imputer.fit_transform(train[features])
    x_test = imputer.transform(test[features])
    model = LGBMClassifier(**LGBM_PARAMS)
    model.fit(x_train, train[BINARY_TARGET].values)
    return features, model.predict_proba(x_test)[:, 1]


def subgroup_rows(test, y_prob, model):
    defs = {
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
        "age": {
            "18-39": (test["age"] >= 18) & (test["age"] < 40),
            "40-59": (test["age"] >= 40) & (test["age"] < 60),
            "60+": test["age"] >= 60,
        },
    }
    y = test[BINARY_TARGET].values
    rows = []
    for group, labels in defs.items():
        for label, mask in labels.items():
            mask = np.asarray(mask)
            if mask.sum() < 30 or len(np.unique(y[mask])) < 2:
                continue
            rows.append({
                "model": model,
                "group": group,
                "subgroup": label,
                "n": int(mask.sum()),
                "prevalence": float(y[mask].mean()),
                **calc_metrics(y[mask], y_prob[mask]),
            })
    return rows


def minus(features, drops):
    drops = set(drops)
    return [f for f in features if f not in drops]


def burden_table():
    rows = [
        ("supplements", "delete", "High burden, high missingness, low real-world reliability for users to estimate nutrient mg from supplements."),
        ("detailed diet nutrients", "delete by default", "Requires diet logging and nutrient estimation; NHANES only gives 1-2 recalls."),
        ("blood pressure", "optional", "Useful and clinically coherent but requires equipment; impute if omitted."),
        ("race", "keep with fairness monitoring", "Predictive and affects subgroup error tradeoffs; ethically sensitive."),
        ("ten-year weight change", "optional / avoid required", "Clinically plausible but recall reliability is poor and missingness is high."),
        ("activity/sleep/mood", "optional module", "Some clinical value but more repeated questionnaire burden."),
        ("alcohol", "keep simple frequency only", "Frequency captures most alcohol signal; detailed grams are burdensome."),
        ("caffeine", "optional trend feature", "Milligram estimates are unreliable for users and only modestly predictive."),
    ]
    return pd.DataFrame(rows, columns=["group", "recommendation", "reason"])


def write_report(out_dir, perf, subgroups, burden):
    baseline = perf.loc[perf["model"] == "baseline_67"].iloc[0]
    rec = perf.loc[perf["model"] == "low_burden_screen_optional_bp"].iloc[0]
    clinical = perf.loc[perf["model"] == "clinical_screen_no_diet_supp"].iloc[0]
    lines = [
        "# Input Reduction From Original 67 Features",
        "",
        "LightGBM-only validation from the restored 67-feature baseline. Variants use the same train/test split and metrics.",
        "",
        "## Performance Summary",
        "",
        perf.to_markdown(index=False, floatfmt=".4f"),
        "",
        "## Recommendation",
        "",
        "Use a two-tier product model:",
        "",
        "1. Default low-burden screening model with optional BP: 18 model features.",
        "2. Optional clinical/lifestyle extension: 29 model features without detailed diet nutrients or supplement nutrient estimates.",
        "",
        f"The 18-feature model AUC is {rec['auc']:.4f} versus baseline 67-feature AUC {baseline['auc']:.4f}.",
        f"The 29-feature clinical screen AUC is {clinical['auc']:.4f}.",
        "",
        "The largest burden reduction should come from deleting supplement nutrient estimates and detailed diet nutrient averages from the required flow. Their real-world measurement burden is high, and the model loss is modest compared with the user-experience gain.",
        "",
        "## Input Group Decisions",
        "",
        burden.to_markdown(index=False),
        "",
        "## Robustness And Fairness Snapshot",
        "",
        subgroups.to_markdown(index=False, floatfmt=".4f"),
        "",
        "## Notes",
        "",
        "- Bootstrap intervals are included for AUC, AUPRC, FNR, Brier, and ECE in the CSV output.",
        "- Feature reduction here is based on held-out performance deltas, calibration, burden/reliability, and subgroup behavior, not SHAP alone.",
        "- The final feature set should still be frozen before external validation to avoid post-test-set tuning.",
    ]
    with open(os.path.join(out_dir, "input_reduction_report.md"), "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    out_dir = os.path.join(RESULTS_DIR, "input_reduction")
    os.makedirs(out_dir, exist_ok=True)
    train = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "train.parquet"))
    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    with open(os.path.join(DATA_PROCESSED_DIR, "features_used.txt")) as f:
        baseline = [line.strip() for line in f if line.strip()]

    variants = {
        "baseline_67": baseline,
        "no_supplements": minus(baseline, SUPPLEMENTS),
        "no_detailed_diet": minus(baseline, DIET_AVG),
        "clinical_screen_no_diet_supp": CLINICAL_SCREEN,
        "clinical_screen_no_bp": minus(CLINICAL_SCREEN, BP),
        "clinical_screen_no_race": minus(CLINICAL_SCREEN, RACE),
        "clinical_screen_no_weight_history": minus(CLINICAL_SCREEN, WEIGHT_HISTORY),
        "clinical_screen_no_alcohol": minus(CLINICAL_SCREEN, ["alcohol_frequency", "alcohol_avg_drinks"]),
        "clinical_screen_no_activity_sleep_mood": minus(CLINICAL_SCREEN, ACTIVITY_SLEEP_MOOD),
        "low_burden_screen_optional_bp": LOW_BURDEN_SCREEN,
        "low_burden_screen_no_bp": LOW_BURDEN_NO_BP,
        "low_burden_no_race": minus(LOW_BURDEN_SCREEN, RACE),
        "low_burden_no_alcohol": minus(LOW_BURDEN_SCREEN, ["alcohol_frequency"]),
    }

    y = test[BINARY_TARGET].values
    perf_rows = []
    preds = {}
    for name, features in variants.items():
        used, y_prob = fit_predict(train, test, features)
        preds[name] = y_prob
        vals = calc_metrics(y, y_prob)
        vals.update(bootstrap_ci(y, y_prob))
        perf_rows.append({"model": name, "n_features": len(used), **vals})

    perf = pd.DataFrame(perf_rows)
    subgroup = pd.DataFrame(
        subgroup_rows(test, preds["baseline_67"], "baseline_67")
        + subgroup_rows(test, preds["low_burden_screen_optional_bp"], "low_burden_screen_optional_bp")
        + subgroup_rows(test, preds["low_burden_no_race"], "low_burden_no_race")
    )
    burden = burden_table()

    perf.to_csv(os.path.join(out_dir, "input_reduction_performance.csv"), index=False)
    subgroup.to_csv(os.path.join(out_dir, "input_reduction_subgroups.csv"), index=False)
    burden.to_csv(os.path.join(out_dir, "input_group_decisions.csv"), index=False)
    write_report(out_dir, perf, subgroup, burden)
    print(perf[["model", "n_features", "auc", "auprc", "fnr", "brier", "ece_10bin"]])
    print(f"Saved report: {os.path.join(out_dir, 'input_reduction_report.md')}")


if __name__ == "__main__":
    main()
