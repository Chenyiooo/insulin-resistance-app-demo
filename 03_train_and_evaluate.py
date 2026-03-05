"""
Step 3: Train ML models, evaluate, SHAP analysis, and subgroup analysis.
- Traditional baselines: FINDRISC (approx), ADA Risk Test, Logistic Regression
- ML models: Random Forest, XGBoost, LightGBM, SVM, MLP
- Evaluation: AUC, AUPRC, Sensitivity, Specificity, F1, Bootstrap CIs
- SHAP explainability analysis
- Subgroup/fairness analysis
"""
import sys
sys.stdout.reconfigure(line_buffering=True)

import os
import json
import warnings
import numpy as np
import pandas as pd
import joblib
from scipy import stats

from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.svm import SVC
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import StratifiedKFold, RandomizedSearchCV
from sklearn.metrics import (
    roc_auc_score, average_precision_score, roc_curve,
    precision_recall_curve, f1_score, confusion_matrix,
    brier_score_loss, classification_report,
)
from sklearn.calibration import calibration_curve

import xgboost as xgb
import lightgbm as lgb
import shap

from config import (
    DATA_PROCESSED_DIR, RESULTS_DIR, FIGURES_DIR, TABLES_DIR, MODELS_DIR,
    PREDICTOR_FEATURES, BINARY_TARGET, MULTICLASS_TARGET,
    SUBGROUPS, RANDOM_STATE,
)

warnings.filterwarnings("ignore")
np.random.seed(RANDOM_STATE)


# ── Load data ──

def load_data():
    """Load preprocessed train/test data."""
    train = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "train.parquet"))
    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))

    with open(os.path.join(DATA_PROCESSED_DIR, "features_used.txt")) as f:
        features = [line.strip() for line in f if line.strip()]

    return train, test, features


# ── Traditional risk scores ──

def compute_findrisc(df):
    """Approximate FINDRISC score using available NHANES variables.
    Original: age, BMI, waist, physical activity, fruit/veg, BP med, high sugar, family history.
    We approximate where exact variables are unavailable.
    """
    score = pd.Series(0.0, index=df.index)

    # Age
    score += np.where(df["age"] < 45, 0,
             np.where(df["age"] < 55, 2,
             np.where(df["age"] < 65, 3, 4)))

    # BMI
    if "bmi" in df.columns:
        score += np.where(df["bmi"] < 25, 0,
                 np.where(df["bmi"] < 30, 1, 3))

    # Waist circumference (sex-specific)
    if "waist_circumference" in df.columns and "sex" in df.columns:
        male = df["sex"] == 1
        score += np.where(
            male,
            np.where(df["waist_circumference"] < 94, 0,
                     np.where(df["waist_circumference"] < 102, 3, 4)),
            np.where(df["waist_circumference"] < 80, 0,
                     np.where(df["waist_circumference"] < 88, 3, 4)),
        )

    # Physical activity (use moderate/vigorous recreation as proxy)
    if "vigorous_recreation" in df.columns:
        active = (df.get("vigorous_recreation", 0) == 1) | (df.get("moderate_recreation", 0) == 1)
        score += np.where(active, 0, 2)

    # BP medication
    if "hypertension_med" in df.columns:
        score += np.where(df["hypertension_med"] == 1, 2, 0)

    # Family history of diabetes
    if "family_diabetes" in df.columns:
        score += np.where(df["family_diabetes"] == 1, 5, 0)

    return score


def compute_ada_risk(df):
    """Compute ADA Diabetes Risk Test score.
    Items: age, sex, gestational diabetes, family diabetes, hypertension, physical inactivity, BMI.
    Score >= 5 = high risk.
    """
    score = pd.Series(0.0, index=df.index)

    # Age
    score += np.where(df["age"] <= 40, 0,
             np.where(df["age"] <= 49, 1,
             np.where(df["age"] <= 59, 2, 3)))

    # Sex (male=1 point)
    if "sex" in df.columns:
        score += np.where(df["sex"] == 1, 1, 0)

    # Gestational diabetes (women only)
    if "gestational_diabetes" in df.columns:
        score += np.where(df["gestational_diabetes"] == 1, 1, 0)

    # Family diabetes
    if "family_diabetes" in df.columns:
        score += np.where(df["family_diabetes"] == 1, 1, 0)

    # Hypertension
    if "hypertension_history" in df.columns:
        score += np.where(df["hypertension_history"] == 1, 1, 0)

    # Physical inactivity
    active = pd.Series(False, index=df.index)
    for col in ["vigorous_recreation", "moderate_recreation", "vigorous_work", "moderate_work"]:
        if col in df.columns:
            active = active | (df[col] == 1)
    score += np.where(~active, 1, 0)

    # BMI
    if "bmi" in df.columns:
        score += np.where(df["bmi"] < 25, 0,
                 np.where(df["bmi"] < 30, 1,
                 np.where(df["bmi"] < 40, 2, 3)))

    return score


# ── Model definitions ──

def get_models_and_params():
    """Define models and their hyperparameter search spaces."""
    models = {
        "Logistic Regression": {
            "model": LogisticRegression(max_iter=1000, random_state=RANDOM_STATE),
            "params": {
                "C": [0.01, 0.1, 1, 10],
                "penalty": ["l2"],
                "class_weight": [None, "balanced"],
            },
            "needs_scaling": True,
        },
        "Random Forest": {
            "model": RandomForestClassifier(random_state=RANDOM_STATE, n_jobs=-1),
            "params": {
                "n_estimators": [200, 500],
                "max_depth": [8, 12, 16, None],
                "min_samples_split": [5, 10, 20],
                "min_samples_leaf": [2, 5, 10],
                "class_weight": [None, "balanced"],
            },
            "needs_scaling": False,
        },
        "XGBoost": {
            "model": xgb.XGBClassifier(
                random_state=RANDOM_STATE, eval_metric="logloss",
                use_label_encoder=False, n_jobs=-1,
            ),
            "params": {
                "n_estimators": [200, 500],
                "max_depth": [4, 6, 8],
                "learning_rate": [0.01, 0.05, 0.1],
                "subsample": [0.8, 1.0],
                "colsample_bytree": [0.8, 1.0],
                "scale_pos_weight": [1, 3, 5],
            },
            "needs_scaling": False,
        },
        "LightGBM": {
            "model": lgb.LGBMClassifier(
                random_state=RANDOM_STATE, verbose=-1, n_jobs=-1,
            ),
            "params": {
                "n_estimators": [200, 500],
                "max_depth": [4, 6, 8, -1],
                "learning_rate": [0.01, 0.05, 0.1],
                "num_leaves": [31, 63, 127],
                "subsample": [0.8, 1.0],
                "is_unbalance": [True, False],
            },
            "needs_scaling": False,
        },
        "SVM": {
            "model": SVC(probability=True, random_state=RANDOM_STATE, cache_size=1000),
            "params": {
                "C": [0.1, 1, 10],
                "kernel": ["rbf"],
                "gamma": ["scale"],
                "class_weight": ["balanced"],
            },
            "needs_scaling": True,
            "subsample": 8000,
        },
        "MLP": {
            "model": MLPClassifier(max_iter=500, random_state=RANDOM_STATE, early_stopping=True),
            "params": {
                "hidden_layer_sizes": [(64, 32), (128, 64), (128, 64, 32)],
                "alpha": [0.0001, 0.001, 0.01],
                "learning_rate_init": [0.001, 0.01],
            },
            "needs_scaling": True,
        },
    }
    return models


# ── Training ──

def train_models(X_train, y_train, X_test, y_test, features):
    """Train all models with hyperparameter search, evaluate on test set."""
    models_config = get_models_and_params()
    results = {}
    trained_models = {}
    scaler = StandardScaler().fit(X_train[features])

    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)

    for name, cfg in models_config.items():
        print(f"\n  Training {name}...")

        X_tr_full = scaler.transform(X_train[features]) if cfg["needs_scaling"] else X_train[features].values
        X_te = scaler.transform(X_test[features]) if cfg["needs_scaling"] else X_test[features].values
        y_tr_full = y_train

        # Subsample for slow models (SVM)
        if "subsample" in cfg and len(y_train) > cfg["subsample"]:
            n_sub = cfg["subsample"]
            rng = np.random.RandomState(RANDOM_STATE)
            idx = rng.choice(len(y_train), n_sub, replace=False)
            X_tr = X_tr_full[idx]
            y_tr = y_tr_full[idx]
            print(f"    (subsampled to {n_sub} for training speed)")
            n_iter = 3
        else:
            X_tr = X_tr_full
            y_tr = y_tr_full
            n_iter = 12

        search = RandomizedSearchCV(
            cfg["model"], cfg["params"],
            n_iter=min(n_iter, len(cfg["params"])),
            cv=cv, scoring="roc_auc",
            random_state=RANDOM_STATE, n_jobs=-1, verbose=0,
        )
        search.fit(X_tr, y_tr)

        best_model = search.best_estimator_

        y_prob = best_model.predict_proba(X_te)[:, 1]
        y_pred = (y_prob >= 0.5).astype(int)

        res = evaluate_model(y_test, y_prob, y_pred, name)
        res["best_params"] = search.best_params_
        res["cv_auc_mean"] = search.best_score_
        results[name] = res
        trained_models[name] = {
            "model": best_model,
            "scaler": scaler if cfg["needs_scaling"] else None,
        }

        print(f"    CV AUC: {search.best_score_:.4f} | Test AUC: {res['auc']:.4f} | "
              f"AUPRC: {res['auprc']:.4f} | F1: {res['f1']:.4f}")

    return results, trained_models, scaler


def evaluate_model(y_true, y_prob, y_pred, name):
    """Compute evaluation metrics for a single model."""
    auc = roc_auc_score(y_true, y_prob)
    auprc = average_precision_score(y_true, y_prob)
    f1 = f1_score(y_true, y_pred)
    brier = brier_score_loss(y_true, y_prob)

    tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
    sensitivity = tp / (tp + fn) if (tp + fn) > 0 else 0
    specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
    ppv = tp / (tp + fp) if (tp + fp) > 0 else 0
    npv = tn / (tn + fn) if (tn + fn) > 0 else 0

    fpr, tpr, thresholds = roc_curve(y_true, y_prob)
    precision_arr, recall_arr, _ = precision_recall_curve(y_true, y_prob)

    # Optimal threshold (Youden's J)
    j_scores = tpr - fpr
    optimal_idx = np.argmax(j_scores)
    optimal_threshold = thresholds[optimal_idx]
    y_pred_optimal = (y_prob >= optimal_threshold).astype(int)
    tn_o, fp_o, fn_o, tp_o = confusion_matrix(y_true, y_pred_optimal).ravel()
    sens_optimal = tp_o / (tp_o + fn_o)
    spec_optimal = tn_o / (tn_o + fp_o)

    return {
        "auc": auc, "auprc": auprc, "f1": f1, "brier": brier,
        "sensitivity": sensitivity, "specificity": specificity,
        "ppv": ppv, "npv": npv,
        "sensitivity_optimal": sens_optimal, "specificity_optimal": spec_optimal,
        "optimal_threshold": optimal_threshold,
        "fpr": fpr.tolist(), "tpr": tpr.tolist(),
        "precision_curve": precision_arr.tolist(), "recall_curve": recall_arr.tolist(),
    }


# ── Bootstrap confidence intervals ──

def bootstrap_auc(y_true, y_prob, n_bootstrap=1000, ci=0.95):
    """Compute bootstrap confidence interval for AUC."""
    rng = np.random.RandomState(RANDOM_STATE)
    aucs = []
    n = len(y_true)
    for _ in range(n_bootstrap):
        idx = rng.choice(n, n, replace=True)
        if len(np.unique(y_true[idx])) < 2:
            continue
        aucs.append(roc_auc_score(y_true[idx], y_prob[idx]))

    alpha = (1 - ci) / 2
    lower = np.percentile(aucs, alpha * 100)
    upper = np.percentile(aucs, (1 - alpha) * 100)
    return np.mean(aucs), lower, upper


# ── Risk scores evaluation ──

def evaluate_risk_scores(X_test, y_test):
    """Evaluate FINDRISC and ADA risk scores on test set."""
    results = {}

    # FINDRISC
    findrisc_scores = compute_findrisc(X_test)
    findrisc_binary = (findrisc_scores >= 12).astype(int)  # Standard cutoff
    if findrisc_scores.std() > 0:
        from sklearn.preprocessing import minmax_scale
        findrisc_prob = minmax_scale(findrisc_scores.fillna(0))
        res = evaluate_model(y_test, findrisc_prob, findrisc_binary, "FINDRISC")
        results["FINDRISC"] = res
        print(f"  FINDRISC  -> AUC: {res['auc']:.4f} | Sens: {res['sensitivity']:.4f} | Spec: {res['specificity']:.4f}")

    # ADA Risk Test
    ada_scores = compute_ada_risk(X_test)
    ada_binary = (ada_scores >= 5).astype(int)  # Standard cutoff
    if ada_scores.std() > 0:
        from sklearn.preprocessing import minmax_scale
        ada_prob = minmax_scale(ada_scores.fillna(0))
        res = evaluate_model(y_test, ada_prob, ada_binary, "ADA Risk Test")
        results["ADA Risk Test"] = res
        print(f"  ADA Risk  -> AUC: {res['auc']:.4f} | Sens: {res['sensitivity']:.4f} | Spec: {res['specificity']:.4f}")

    return results


# ── SHAP analysis ──

def run_shap_analysis(model, X_test, features, model_name="XGBoost"):
    """Run SHAP analysis on the best model."""
    print(f"\n  Running SHAP analysis on {model_name}...")

    X_sample = X_test[features].copy()
    if len(X_sample) > 2000:
        X_sample = X_sample.sample(2000, random_state=RANDOM_STATE)

    if model_name in ("XGBoost", "LightGBM", "Random Forest"):
        explainer = shap.TreeExplainer(model)
    else:
        explainer = shap.KernelExplainer(
            model.predict_proba, shap.sample(X_test[features], 100)
        )

    shap_values = explainer.shap_values(X_sample)

    # For tree models, shap_values may be a list [class0, class1]
    if isinstance(shap_values, list):
        shap_values = shap_values[1]  # positive class

    # Global feature importance (mean absolute SHAP)
    importance = pd.DataFrame({
        "feature": features,
        "mean_abs_shap": np.abs(shap_values).mean(axis=0),
    }).sort_values("mean_abs_shap", ascending=False)

    print(f"\n  Top 10 features by SHAP importance:")
    for _, row in importance.head(10).iterrows():
        print(f"    {row['feature']:30s}: {row['mean_abs_shap']:.4f}")

    return shap_values, X_sample, importance


# ── Subgroup analysis ──

def run_subgroup_analysis(trained_models, scaler, X_test, y_test, features, best_model_name):
    """Evaluate model performance across demographic subgroups."""
    print(f"\n  Running subgroup analysis...")

    best_info = trained_models[best_model_name]
    model = best_info["model"]
    needs_scaling = best_info["scaler"] is not None

    subgroup_results = {}

    for group_name, group_defs in SUBGROUPS.items():
        subgroup_results[group_name] = {}
        for label, mask_fn in group_defs.items():
            try:
                mask = mask_fn(X_test)
                X_sub = X_test.loc[mask, features]
                y_sub = y_test[mask.values] if hasattr(mask, 'values') else y_test[mask]

                if len(y_sub) < 50 or len(np.unique(y_sub)) < 2:
                    continue

                if needs_scaling:
                    X_input = scaler.transform(X_sub)
                else:
                    X_input = X_sub.values

                y_prob = model.predict_proba(X_input)[:, 1]
                auc = roc_auc_score(y_sub, y_prob)
                y_sub_arr = y_sub if isinstance(y_sub, np.ndarray) else y_sub.values
                auc_mean, auc_lo, auc_hi = bootstrap_auc(
                    y_sub_arr, y_prob, n_bootstrap=500
                )

                subgroup_results[group_name][label] = {
                    "n": int(len(y_sub)),
                    "prevalence": float(y_sub.mean()),
                    "auc": float(auc),
                    "auc_ci_lower": float(auc_lo),
                    "auc_ci_upper": float(auc_hi),
                }
                print(f"    {group_name:12s} / {label:20s}: n={len(y_sub):>5d}, "
                      f"AUC={auc:.4f} [{auc_lo:.4f}-{auc_hi:.4f}]")
            except Exception as e:
                print(f"    {group_name:12s} / {label:20s}: ERROR - {e}")

    return subgroup_results


# ── Save results ──

def save_results(all_results, shap_data, subgroup_results, trained_models, scaler):
    """Save all results to disk."""
    os.makedirs(TABLES_DIR, exist_ok=True)
    os.makedirs(MODELS_DIR, exist_ok=True)

    # Performance table
    perf_rows = []
    for name, res in all_results.items():
        perf_rows.append({
            "Model": name,
            "AUC": f"{res['auc']:.4f}",
            "AUPRC": f"{res['auprc']:.4f}",
            "Sensitivity": f"{res['sensitivity']:.4f}",
            "Specificity": f"{res['specificity']:.4f}",
            "F1": f"{res['f1']:.4f}",
            "Brier": f"{res.get('brier', 0):.4f}",
            "Sens@Optimal": f"{res.get('sensitivity_optimal', 0):.4f}",
            "Spec@Optimal": f"{res.get('specificity_optimal', 0):.4f}",
        })
    perf_df = pd.DataFrame(perf_rows)
    perf_df.to_csv(os.path.join(TABLES_DIR, "model_performance.csv"), index=False)
    print(f"\n  Saved performance table")

    # Subgroup table
    sub_rows = []
    for group, labels in subgroup_results.items():
        for label, vals in labels.items():
            sub_rows.append({
                "Group": group,
                "Subgroup": label,
                "N": vals["n"],
                "Prevalence": f"{vals['prevalence']:.3f}",
                "AUC": f"{vals['auc']:.4f}",
                "AUC_CI": f"[{vals['auc_ci_lower']:.4f}-{vals['auc_ci_upper']:.4f}]",
            })
    sub_df = pd.DataFrame(sub_rows)
    sub_df.to_csv(os.path.join(TABLES_DIR, "subgroup_analysis.csv"), index=False)

    # SHAP importance
    if shap_data:
        shap_data["importance"].to_csv(
            os.path.join(TABLES_DIR, "shap_importance.csv"), index=False
        )

    # All results as JSON (for figure generation)
    serializable = {}
    for name, res in all_results.items():
        serializable[name] = {
            k: v for k, v in res.items()
            if k not in ("best_params",)
        }
        if "best_params" in res:
            serializable[name]["best_params"] = {
                str(k): str(v) for k, v in res["best_params"].items()
            }

    with open(os.path.join(RESULTS_DIR, "all_results.json"), "w") as f:
        json.dump(serializable, f, indent=2, default=str)

    with open(os.path.join(RESULTS_DIR, "subgroup_results.json"), "w") as f:
        json.dump(subgroup_results, f, indent=2)

    # Save models
    for name, info in trained_models.items():
        safe_name = name.lower().replace(" ", "_")
        joblib.dump(info["model"], os.path.join(MODELS_DIR, f"{safe_name}.joblib"))

    if scaler is not None:
        joblib.dump(scaler, os.path.join(MODELS_DIR, "scaler.joblib"))

    print(f"  All results saved.")


# ── Main ──

def main():
    print("=" * 60)
    print("  Model Training & Evaluation Pipeline")
    print("=" * 60)

    # Load data
    train, test, features = load_data()
    features = [f for f in features if f in train.columns and f in test.columns]

    X_train, y_train = train, train[BINARY_TARGET].values
    X_test, y_test = test, test[BINARY_TARGET].values

    print(f"\n  Features ({len(features)}): {features}")
    print(f"  Train: {len(X_train)}, Test: {len(X_test)}")
    print(f"  Train prevalence: {y_train.mean():.3f}, Test prevalence: {y_test.mean():.3f}")

    # Evaluate traditional risk scores
    print(f"\n{'='*60}")
    print(f"  Evaluating Traditional Risk Scores")
    print(f"{'='*60}")
    risk_results = evaluate_risk_scores(X_test, y_test)

    # Train ML models
    print(f"\n{'='*60}")
    print(f"  Training ML Models")
    print(f"{'='*60}")
    ml_results, trained_models, scaler = train_models(X_train, y_train, X_test, y_test, features)

    # Combine results
    all_results = {**risk_results, **ml_results}

    # Bootstrap CIs for all ML models
    print(f"\n{'='*60}")
    print(f"  Bootstrap Confidence Intervals (1000 iterations)")
    print(f"{'='*60}")
    for name, info in trained_models.items():
        model = info["model"]
        needs_scaling = info["scaler"] is not None
        X_te = scaler.transform(X_test[features]) if needs_scaling else X_test[features].values
        y_prob = model.predict_proba(X_te)[:, 1]
        mean_auc, lo, hi = bootstrap_auc(y_test, y_prob)
        all_results[name]["auc_ci_lower"] = lo
        all_results[name]["auc_ci_upper"] = hi
        print(f"  {name:25s}: AUC = {mean_auc:.4f} [{lo:.4f} - {hi:.4f}]")

    # Determine best model
    best_name = max(
        [(k, v["auc"]) for k, v in ml_results.items()],
        key=lambda x: x[1]
    )[0]
    print(f"\n  Best model: {best_name} (AUC = {all_results[best_name]['auc']:.4f})")

    # SHAP analysis on best model
    shap_values, X_shap, importance = run_shap_analysis(
        trained_models[best_name]["model"], X_test, features, best_name
    )
    shap_data = {
        "shap_values": shap_values,
        "X_sample": X_shap,
        "importance": importance,
        "best_model_name": best_name,
    }

    # Save SHAP values for figure generation
    np.save(os.path.join(RESULTS_DIR, "shap_values.npy"), shap_values)
    X_shap.to_parquet(os.path.join(RESULTS_DIR, "shap_X_sample.parquet"))

    # Subgroup analysis
    print(f"\n{'='*60}")
    print(f"  Subgroup / Fairness Analysis")
    print(f"{'='*60}")
    subgroup_results = run_subgroup_analysis(
        trained_models, scaler, X_test, y_test, features, best_name
    )

    # Save everything
    save_results(all_results, shap_data, subgroup_results, trained_models, scaler)

    print(f"\n{'='*60}")
    print(f"  Pipeline Complete!")
    print(f"{'='*60}")

    return all_results, trained_models, shap_data, subgroup_results


if __name__ == "__main__":
    main()
