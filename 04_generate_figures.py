"""
Step 4: Generate all publication-quality figures and tables.
- Figure 1: CONSORT-style sample flow diagram
- Figure 2: ROC curves comparison (all models)
- Figure 3: SHAP beeswarm plot (global feature importance)
- Figure 4: Calibration curves
- Figure 5: Decision Curve Analysis (DCA)
- Figure 6: SHAP dependence plots for top features
- Table 1: Baseline characteristics
- Table 2: Model performance comparison
- Table 3: Subgroup analysis
"""
import os
import json
import warnings
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import seaborn as sns
import shap
import joblib
from sklearn.calibration import calibration_curve

from config import (
    DATA_PROCESSED_DIR, RESULTS_DIR, FIGURES_DIR, TABLES_DIR, MODELS_DIR,
    PREDICTOR_FEATURES, BINARY_TARGET, MULTICLASS_TARGET, SUBGROUPS,
    DIETARY_NUTRIENTS,
)

warnings.filterwarnings("ignore")

plt.rcParams.update({
    "font.family": "serif",
    "font.size": 10,
    "axes.labelsize": 11,
    "axes.titlesize": 12,
    "xtick.labelsize": 9,
    "ytick.labelsize": 9,
    "legend.fontsize": 9,
    "figure.dpi": 300,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
    "savefig.pad_inches": 0.1,
})

COLORS = {
    "FINDRISC": "#888888",
    "ADA Risk Test": "#AAAAAA",
    "Logistic Regression": "#1b9e77",
    "Random Forest": "#d95f02",
    "XGBoost": "#e7298a",
    "LightGBM": "#7570b3",
    "SVM": "#66a61e",
    "MLP": "#e6ab02",
}

FEATURE_DISPLAY_NAMES = {
    "age": "Age", "sex": "Sex", "race": "Race/Ethnicity",
    "education": "Education", "income_ratio": "Income-Poverty Ratio",
    "bmi": "BMI", "waist_circumference": "Waist Circumference",
    "weight": "Weight", "height": "Height",
    "systolic_bp": "Systolic BP", "diastolic_bp": "Diastolic BP", "pulse": "Pulse",
    "family_diabetes": "Family Diabetes Hx", "hypertension_history": "Hypertension Hx",
    "hypertension_med": "Hypertension Medication", "high_cholesterol": "High Cholesterol Hx",
    "smoking_status": "Smoking Status",
    "alcohol_frequency": "Alcohol Frequency", "alcohol_avg_drinks": "Alcohol Drinks/Day",
    "vigorous_work": "Vigorous Work", "moderate_work": "Moderate Work",
    "vigorous_recreation": "Vigorous Recreation", "moderate_recreation": "Moderate Recreation",
    "sedentary_minutes": "Sedentary Time (min)", "sleep_hours": "Sleep Hours",
    "sleep_trouble": "Sleep Trouble", "phq9_score": "PHQ-9 Score",
    "gestational_diabetes": "Gestational Diabetes",
    "weight_change_pct": "Weight Change (%)", "waist_height_ratio": "Waist-Height Ratio",
}

for nutrient, label in DIETARY_NUTRIENTS.items():
    FEATURE_DISPLAY_NAMES[f"diet_{nutrient}_avg"] = f"Diet {label}"
    FEATURE_DISPLAY_NAMES[f"supp_{nutrient}"] = f"Supplement {label}"

FEATURE_DISPLAY_NAMES.update({
    "diet_recall_days": "Diet Recall Days",
    "supplement_used": "Dietary Supplement Use",
    "supplement_count": "# Dietary Supplements",
    "antacid_used": "Antacid Use",
    "antacid_count": "# Antacids",
})


def load_results():
    """Load all saved results."""
    with open(os.path.join(RESULTS_DIR, "all_results.json")) as f:
        all_results = json.load(f)
    with open(os.path.join(RESULTS_DIR, "subgroup_results.json")) as f:
        subgroup_results = json.load(f)
    return all_results, subgroup_results


# ── Figure 1: CONSORT Flow Diagram ──

def fig1_consort_flow(save_path=None):
    """Draw a CONSORT-style sample selection flow diagram."""
    flow_path = os.path.join(DATA_PROCESSED_DIR, "sample_flow.csv")
    if not os.path.exists(flow_path):
        print("  [SKIP] Figure 1: sample_flow.csv not found")
        return

    flow = pd.read_csv(flow_path)
    steps = flow.set_index("step")["n"].to_dict()

    fig, ax = plt.subplots(figsize=(8, 10))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 12)
    ax.axis("off")

    box_style = dict(boxstyle="round,pad=0.5", facecolor="#E8F0FE", edgecolor="#4A86C8", linewidth=1.5)
    excl_style = dict(boxstyle="round,pad=0.4", facecolor="#FFF3E0", edgecolor="#E65100", linewidth=1)

    y_positions = list(range(11, 0, -2))
    labels = list(steps.keys())
    values = list(steps.values())

    for i, (label, n) in enumerate(zip(labels, values)):
        y = y_positions[i] if i < len(y_positions) else y_positions[-1]
        display_label = label.replace("_", " ").title()
        ax.text(5, y, f"{display_label}\nn = {n:,}", ha="center", va="center",
                fontsize=10, fontweight="bold", bbox=box_style)

        if i > 0:
            excluded = values[i - 1] - n
            if excluded > 0:
                ax.annotate("", xy=(5, y + 0.7), xytext=(5, y_positions[i - 1] - 0.7),
                            arrowprops=dict(arrowstyle="->", lw=1.5, color="#4A86C8"))
                prev_label = labels[i - 1].replace("_", " ").title()
                ax.text(8.5, (y + y_positions[i - 1]) / 2,
                        f"Excluded:\nn = {excluded:,}",
                        ha="center", va="center", fontsize=8, bbox=excl_style)

    ax.set_title("Figure 1. Study Sample Selection Flow", fontsize=13, fontweight="bold", pad=20)
    if save_path:
        plt.savefig(save_path)
    plt.close()
    print(f"  Figure 1 saved: {save_path}")


# ── Figure 2: ROC Curves ──

def fig2_roc_curves(all_results, save_path=None):
    """Plot ROC curves for all models on one figure."""
    fig, ax = plt.subplots(figsize=(8, 7))

    for name, res in all_results.items():
        if "fpr" not in res or "tpr" not in res:
            continue
        fpr = np.array(res["fpr"])
        tpr = np.array(res["tpr"])
        auc_val = res["auc"]
        color = COLORS.get(name, "#333333")
        ci_str = ""
        if "auc_ci_lower" in res and "auc_ci_upper" in res:
            ci_str = f" [{res['auc_ci_lower']:.3f}-{res['auc_ci_upper']:.3f}]"
        ax.plot(fpr, tpr, label=f"{name} (AUC={auc_val:.3f}{ci_str})",
                color=color, linewidth=2)

    ax.plot([0, 1], [0, 1], "k--", linewidth=1, alpha=0.5, label="Chance")
    ax.set_xlabel("False Positive Rate (1 - Specificity)")
    ax.set_ylabel("True Positive Rate (Sensitivity)")
    ax.set_title("Figure 2. ROC Curves — All Models", fontweight="bold")
    ax.legend(loc="lower right", framealpha=0.9)
    ax.set_xlim([-0.01, 1.01])
    ax.set_ylim([-0.01, 1.01])
    ax.grid(True, alpha=0.3)

    if save_path:
        plt.savefig(save_path)
    plt.close()
    print(f"  Figure 2 saved: {save_path}")


# ── Figure 3: SHAP Beeswarm Plot ──

def fig3_shap_beeswarm(save_path=None):
    """Create SHAP beeswarm (summary) plot."""
    shap_path = os.path.join(RESULTS_DIR, "shap_values.npy")
    x_path = os.path.join(RESULTS_DIR, "shap_X_sample.parquet")

    if not os.path.exists(shap_path) or not os.path.exists(x_path):
        print("  [SKIP] Figure 3: SHAP data not found")
        return

    shap_values = np.load(shap_path)
    X_sample = pd.read_parquet(x_path)

    # Rename features for display
    X_display = X_sample.rename(columns=FEATURE_DISPLAY_NAMES)
    display_features = [FEATURE_DISPLAY_NAMES.get(c, c) for c in X_sample.columns]

    fig, ax = plt.subplots(figsize=(10, 8))
    shap.summary_plot(
        shap_values, X_display,
        feature_names=display_features,
        max_display=20, show=False, plot_size=None,
    )
    plt.title("Figure 3. SHAP Feature Importance (Beeswarm Plot)", fontweight="bold", pad=15)
    plt.tight_layout()

    if save_path:
        plt.savefig(save_path)
    plt.close()
    print(f"  Figure 3 saved: {save_path}")


# ── Figure 4: Calibration Curves ──

def fig4_calibration_curves(save_path=None):
    """Plot calibration curves for all ML models."""
    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    with open(os.path.join(DATA_PROCESSED_DIR, "features_used.txt")) as f:
        features = [l.strip() for l in f if l.strip()]

    features = [f for f in features if f in test.columns]
    y_test = test[BINARY_TARGET].values

    fig, ax = plt.subplots(figsize=(8, 7))

    model_files = {
        "Logistic Regression": "logistic_regression",
        "Random Forest": "random_forest",
        "XGBoost": "xgboost",
        "LightGBM": "lightgbm",
        "SVM": "svm",
        "MLP": "mlp",
    }

    scaler_path = os.path.join(MODELS_DIR, "scaler.joblib")
    scaler = joblib.load(scaler_path) if os.path.exists(scaler_path) else None
    needs_scaling = {"Logistic Regression", "SVM", "MLP"}

    for display_name, file_name in model_files.items():
        model_path = os.path.join(MODELS_DIR, f"{file_name}.joblib")
        if not os.path.exists(model_path):
            continue

        model = joblib.load(model_path)
        X = test[features]
        if display_name in needs_scaling and scaler is not None:
            X_input = scaler.transform(X)
        else:
            X_input = X.values

        y_prob = model.predict_proba(X_input)[:, 1]
        prob_true, prob_pred = calibration_curve(y_test, y_prob, n_bins=10, strategy="uniform")

        color = COLORS.get(display_name, "#333333")
        ax.plot(prob_pred, prob_true, "o-", label=display_name, color=color, linewidth=2, markersize=5)

    ax.plot([0, 1], [0, 1], "k--", linewidth=1, alpha=0.5, label="Perfectly Calibrated")
    ax.set_xlabel("Mean Predicted Probability")
    ax.set_ylabel("Observed Frequency")
    ax.set_title("Figure 4. Calibration Curves", fontweight="bold")
    ax.legend(loc="upper left", framealpha=0.9)
    ax.set_xlim([-0.01, 1.01])
    ax.set_ylim([-0.01, 1.01])
    ax.grid(True, alpha=0.3)

    if save_path:
        plt.savefig(save_path)
    plt.close()
    print(f"  Figure 4 saved: {save_path}")


# ── Figure 5: Decision Curve Analysis ──

def fig5_dca(save_path=None):
    """Decision Curve Analysis — net benefit vs threshold probability."""
    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    with open(os.path.join(DATA_PROCESSED_DIR, "features_used.txt")) as f:
        features = [l.strip() for l in f if l.strip()]

    features = [f for f in features if f in test.columns]
    y_test = test[BINARY_TARGET].values
    prevalence = y_test.mean()

    thresholds = np.arange(0.01, 0.99, 0.01)

    fig, ax = plt.subplots(figsize=(8, 6))

    # Treat All
    net_benefit_all = prevalence - (1 - prevalence) * thresholds / (1 - thresholds)
    ax.plot(thresholds, net_benefit_all, "k-", linewidth=1, alpha=0.6, label="Treat All")
    ax.axhline(0, color="gray", linewidth=0.5, linestyle="--", label="Treat None")

    model_files = {
        "XGBoost": ("xgboost", False),
        "LightGBM": ("lightgbm", False),
        "Random Forest": ("random_forest", False),
        "Logistic Regression": ("logistic_regression", True),
    }

    scaler_path = os.path.join(MODELS_DIR, "scaler.joblib")
    scaler = joblib.load(scaler_path) if os.path.exists(scaler_path) else None

    for display_name, (file_name, needs_scale) in model_files.items():
        model_path = os.path.join(MODELS_DIR, f"{file_name}.joblib")
        if not os.path.exists(model_path):
            continue

        model = joblib.load(model_path)
        X = test[features]
        if needs_scale and scaler is not None:
            X_input = scaler.transform(X)
        else:
            X_input = X.values

        y_prob = model.predict_proba(X_input)[:, 1]

        net_benefits = []
        for t in thresholds:
            y_pred = (y_prob >= t).astype(int)
            tp = np.sum((y_pred == 1) & (y_test == 1))
            fp = np.sum((y_pred == 1) & (y_test == 0))
            n = len(y_test)
            nb = tp / n - fp / n * t / (1 - t)
            net_benefits.append(nb)

        color = COLORS.get(display_name, "#333333")
        ax.plot(thresholds, net_benefits, label=display_name, color=color, linewidth=2)

    ax.set_xlabel("Threshold Probability")
    ax.set_ylabel("Net Benefit")
    ax.set_title("Figure 5. Decision Curve Analysis", fontweight="bold")
    ax.legend(loc="upper right", framealpha=0.9)
    ax.set_xlim([0, 0.8])
    ax.set_ylim([-0.05, max(0.3, prevalence + 0.05)])
    ax.grid(True, alpha=0.3)

    if save_path:
        plt.savefig(save_path)
    plt.close()
    print(f"  Figure 5 saved: {save_path}")


# ── Figure 6: SHAP Dependence Plots ──

def fig6_shap_dependence(save_path=None):
    """SHAP dependence plots for top 4 features."""
    shap_path = os.path.join(RESULTS_DIR, "shap_values.npy")
    x_path = os.path.join(RESULTS_DIR, "shap_X_sample.parquet")

    if not os.path.exists(shap_path) or not os.path.exists(x_path):
        print("  [SKIP] Figure 6: SHAP data not found")
        return

    shap_values = np.load(shap_path)
    X_sample = pd.read_parquet(x_path)

    importance = np.abs(shap_values).mean(axis=0)
    top_idx = np.argsort(importance)[::-1][:4]
    top_features = [X_sample.columns[i] for i in top_idx]

    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    for i, (feat, ax_) in enumerate(zip(top_features, axes.flat)):
        feat_idx = list(X_sample.columns).index(feat)
        display_name = FEATURE_DISPLAY_NAMES.get(feat, feat)

        scatter = ax_.scatter(
            X_sample[feat], shap_values[:, feat_idx],
            c=X_sample[feat], cmap="coolwarm", alpha=0.4, s=5,
            rasterized=True,
        )
        ax_.set_xlabel(display_name)
        ax_.set_ylabel(f"SHAP value for {display_name}")
        ax_.axhline(0, color="gray", linewidth=0.5, linestyle="--")
        ax_.grid(True, alpha=0.2)

    fig.suptitle("Figure 6. SHAP Dependence Plots (Top 4 Features)", fontweight="bold", y=1.01)
    plt.tight_layout()
    if save_path:
        plt.savefig(save_path)
    plt.close()
    print(f"  Figure 6 saved: {save_path}")


# ── Table 1: Baseline Characteristics ──

def table1_baseline(save_path=None):
    """Generate Table 1 — baseline characteristics by diabetes status."""
    df = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "full_dataset.parquet"))

    labels = {0: "Normal", 1: "Prediabetes", 2: "Diabetes"}
    df["diabetes_group"] = df[MULTICLASS_TARGET].map(labels)

    continuous_vars = [
        "age", "bmi", "waist_circumference", "systolic_bp", "diastolic_bp",
        "sleep_hours", "sedentary_minutes", "phq9_score",
    ]
    continuous_vars = [v for v in continuous_vars if v in df.columns]

    categorical_vars = [
        "sex", "race", "smoking_status", "family_diabetes",
        "hypertension_history", "high_cholesterol",
    ]
    categorical_vars = [v for v in categorical_vars if v in df.columns]

    rows = []
    groups = ["Normal", "Prediabetes", "Diabetes"]

    # Sample size
    row = {"Variable": "N"}
    for g in groups:
        n = (df["diabetes_group"] == g).sum()
        row[g] = str(n)
    rows.append(row)

    # Continuous variables: mean (SD)
    for var in continuous_vars:
        row = {"Variable": FEATURE_DISPLAY_NAMES.get(var, var)}
        for g in groups:
            subset = df.loc[df["diabetes_group"] == g, var].dropna()
            row[g] = f"{subset.mean():.1f} ({subset.std():.1f})"
        rows.append(row)

    # Categorical variables: n (%)
    for var in categorical_vars:
        vals = sorted(df[var].dropna().unique())
        for val in vals:
            display_var = FEATURE_DISPLAY_NAMES.get(var, var)
            row = {"Variable": f"{display_var} = {int(val)}"}
            for g in groups:
                subset = df[df["diabetes_group"] == g]
                n_val = (subset[var] == val).sum()
                pct = n_val / len(subset) * 100 if len(subset) > 0 else 0
                row[g] = f"{n_val} ({pct:.1f}%)"
            rows.append(row)

    table1 = pd.DataFrame(rows)
    if save_path:
        table1.to_csv(save_path, index=False)
    print(f"  Table 1 saved: {save_path}")
    return table1


# ── Figure 7: SHAP Waterfall (individual case studies) ──

def fig7_shap_waterfall(save_path_prefix=None):
    """SHAP waterfall plots for 2 representative cases."""
    shap_path = os.path.join(RESULTS_DIR, "shap_values.npy")
    x_path = os.path.join(RESULTS_DIR, "shap_X_sample.parquet")

    if not os.path.exists(shap_path) or not os.path.exists(x_path):
        print("  [SKIP] Figure 7: SHAP data not found")
        return

    shap_vals = np.load(shap_path)
    X_sample = pd.read_parquet(x_path)

    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    y_test = test[BINARY_TARGET].values

    common_idx = X_sample.index.intersection(test.index)
    if len(common_idx) == 0:
        print("  [SKIP] Figure 7: No matching indices")
        return

    # True positive and true negative examples
    y_subset = test.loc[common_idx, BINARY_TARGET]
    sample_map = {i: idx for i, idx in enumerate(X_sample.index) if idx in common_idx}

    tp_candidates = [k for k, v in sample_map.items() if y_subset.get(v, -1) == 1]
    tn_candidates = [k for k, v in sample_map.items() if y_subset.get(v, -1) == 0]

    cases = []
    if tp_candidates:
        cases.append(("High Risk Case", tp_candidates[0]))
    if tn_candidates:
        cases.append(("Low Risk Case", tn_candidates[0]))

    X_display = X_sample.rename(columns=FEATURE_DISPLAY_NAMES)

    for label, idx in cases:
        fig, ax = plt.subplots(figsize=(10, 6))
        base_value = shap_vals.mean()
        explanation = shap.Explanation(
            values=shap_vals[idx],
            base_values=base_value,
            data=X_display.iloc[idx].values,
            feature_names=X_display.columns.tolist(),
        )
        shap.plots.waterfall(explanation, max_display=15, show=False)
        plt.title(f"Figure 7. SHAP Waterfall — {label}", fontweight="bold")
        plt.tight_layout()
        if save_path_prefix:
            safe_label = label.lower().replace(" ", "_")
            path = f"{save_path_prefix}_{safe_label}.png"
            plt.savefig(path)
            print(f"  Figure 7 ({label}) saved: {path}")
        plt.close()


# ── Figure 8: Subgroup AUC Forest Plot ──

def fig8_subgroup_forest(subgroup_results, save_path=None):
    """Forest plot of AUC across subgroups."""
    fig, ax = plt.subplots(figsize=(10, 8))

    labels = []
    aucs = []
    ci_lows = []
    ci_highs = []
    y_positions = []
    colors = []
    group_colors = {"age_group": "#1b9e77", "sex": "#d95f02", "race": "#7570b3", "bmi_group": "#e7298a"}

    pos = 0
    for group, sublabels in subgroup_results.items():
        labels.append(f"** {group.replace('_', ' ').title()} **")
        aucs.append(None)
        ci_lows.append(None)
        ci_highs.append(None)
        y_positions.append(pos)
        colors.append("white")
        pos += 1

        for sublabel, vals in sublabels.items():
            labels.append(f"  {sublabel} (n={vals['n']:,})")
            aucs.append(vals["auc"])
            ci_lows.append(vals["auc_ci_lower"])
            ci_highs.append(vals["auc_ci_upper"])
            y_positions.append(pos)
            colors.append(group_colors.get(group, "#333333"))
            pos += 1
        pos += 0.5

    y_pos_valid = []
    auc_valid = []
    ci_lo_valid = []
    ci_hi_valid = []
    color_valid = []
    labels_valid = []

    for i, a in enumerate(aucs):
        if a is not None:
            y_pos_valid.append(y_positions[i])
            auc_valid.append(a)
            ci_lo_valid.append(ci_lows[i])
            ci_hi_valid.append(ci_highs[i])
            color_valid.append(colors[i])
            labels_valid.append(labels[i])

    y_pos_valid = np.array(y_pos_valid)
    auc_valid = np.array(auc_valid)
    ci_lo_valid = np.array(ci_lo_valid)
    ci_hi_valid = np.array(ci_hi_valid)

    ax.errorbar(
        auc_valid, y_pos_valid,
        xerr=[auc_valid - ci_lo_valid, ci_hi_valid - auc_valid],
        fmt="o", color="#333333", markersize=6, capsize=3, linewidth=1.5,
    )

    ax.set_yticks(y_positions)
    ax.set_yticklabels(labels, fontsize=9)
    ax.invert_yaxis()
    ax.set_xlabel("AUC (95% CI)")
    ax.set_title("Figure 8. Model Performance Across Subgroups", fontweight="bold")
    ax.axvline(0.5, color="gray", linestyle="--", alpha=0.5)
    ax.grid(True, axis="x", alpha=0.3)
    ax.set_xlim([0.45, 1.0])

    plt.tight_layout()
    if save_path:
        plt.savefig(save_path)
    plt.close()
    print(f"  Figure 8 saved: {save_path}")


# ── Main ──

def main():
    print("=" * 60)
    print("  Generating Figures & Tables")
    print("=" * 60)

    os.makedirs(FIGURES_DIR, exist_ok=True)
    os.makedirs(TABLES_DIR, exist_ok=True)

    all_results, subgroup_results = load_results()

    # Figures
    fig1_consort_flow(os.path.join(FIGURES_DIR, "fig1_consort_flow.png"))
    fig2_roc_curves(all_results, os.path.join(FIGURES_DIR, "fig2_roc_curves.png"))
    fig3_shap_beeswarm(os.path.join(FIGURES_DIR, "fig3_shap_beeswarm.png"))
    fig4_calibration_curves(os.path.join(FIGURES_DIR, "fig4_calibration.png"))
    fig5_dca(os.path.join(FIGURES_DIR, "fig5_dca.png"))
    fig6_shap_dependence(os.path.join(FIGURES_DIR, "fig6_shap_dependence.png"))
    fig7_shap_waterfall(os.path.join(FIGURES_DIR, "fig7_waterfall"))
    fig8_subgroup_forest(subgroup_results, os.path.join(FIGURES_DIR, "fig8_subgroup_forest.png"))

    # Tables
    table1_baseline(os.path.join(TABLES_DIR, "table1_baseline.csv"))

    print(f"\n{'='*60}")
    print(f"  All figures and tables generated!")
    print(f"  Figures: {FIGURES_DIR}")
    print(f"  Tables:  {TABLES_DIR}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
