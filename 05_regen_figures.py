"""
Regenerate all figures for AMIA paper:
- Compact size for journal formatting
- NO embedded titles/captions (handled by LaTeX)
- Publication-quality styling
"""
import sys
sys.stdout.reconfigure(line_buffering=True)

import os
import json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import seaborn as sns
import shap
import joblib
from sklearn.calibration import calibration_curve
from sklearn.metrics import roc_auc_score

from config import (
    DATA_PROCESSED_DIR, RESULTS_DIR, MODELS_DIR,
    BINARY_TARGET, SUBGROUPS, RANDOM_STATE, DIETARY_NUTRIENTS,
)

OUT_DIR = os.path.join(os.path.dirname(__file__), "paper", "figures")
os.makedirs(OUT_DIR, exist_ok=True)

plt.rcParams.update({
    "font.family": "serif",
    "font.serif": ["Times New Roman", "Times", "DejaVu Serif"],
    "font.size": 8,
    "axes.labelsize": 9,
    "axes.titlesize": 9,
    "xtick.labelsize": 7.5,
    "ytick.labelsize": 7.5,
    "legend.fontsize": 7,
    "figure.dpi": 300,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
    "savefig.pad_inches": 0.05,
    "axes.linewidth": 0.6,
    "xtick.major.width": 0.5,
    "ytick.major.width": 0.5,
    "lines.linewidth": 1.2,
})

COLORS = {
    "FINDRISC": "#999999",
    "ADA Risk Test": "#bbbbbb",
    "Logistic Regression": "#1b9e77",
    "Random Forest": "#d95f02",
    "XGBoost": "#e7298a",
    "LightGBM": "#7570b3",
    "SVM": "#66a61e",
    "MLP": "#e6ab02",
}

FEAT_NAMES = {
    "age": "Age", "sex": "Sex", "race": "Race/Ethnicity",
    "education": "Education", "income_ratio": "Income-Poverty Ratio",
    "bmi": "BMI", "waist_circumference": "Waist Circumference",
    "weight": "Weight", "height": "Height",
    "systolic_bp": "Systolic BP", "diastolic_bp": "Diastolic BP", "pulse": "Pulse",
    "family_diabetes": "Family Diabetes Hx", "hypertension_history": "Hypertension Hx",
    "hypertension_med": "Hypertension Medication", "high_cholesterol": "High Cholesterol Hx",
    "smoking_status": "Smoking Status",
    "alcohol_frequency": "Alcohol Frequency", "alcohol_avg_drinks": "Alcohol Drinks/Day",
    "vigorous_work": "Vigorous Work Activity", "moderate_work": "Moderate Work Activity",
    "vigorous_recreation": "Vigorous Recreation", "moderate_recreation": "Moderate Recreation",
    "sedentary_minutes": "Sedentary Time (min)", "sleep_hours": "Sleep Duration (h)",
    "sleep_trouble": "Sleep Disturbance", "phq9_score": "PHQ-9 Depression Score",
    "gestational_diabetes": "Gestational Diabetes Hx",
    "weight_change_pct": "10-yr Weight Change (%)", "waist_height_ratio": "Waist-to-Height Ratio",
}

for nutrient, label in DIETARY_NUTRIENTS.items():
    FEAT_NAMES[f"diet_{nutrient}_avg"] = f"Diet {label}"
    FEAT_NAMES[f"supp_{nutrient}"] = f"Supplement {label}"

FEAT_NAMES.update({
    "diet_recall_days": "Diet Recall Days",
    "supplement_used": "Dietary Supplement Use",
    "supplement_count": "# Dietary Supplements",
    "antacid_used": "Antacid Use",
    "antacid_count": "# Antacids",
})


def load_all():
    with open(os.path.join(RESULTS_DIR, "all_results.json")) as f:
        results = json.load(f)
    with open(os.path.join(RESULTS_DIR, "subgroup_results.json")) as f:
        subgroup = json.load(f)
    return results, subgroup


# ── Figure 1: CONSORT Flow ──
def fig1():
    flow_path = os.path.join(DATA_PROCESSED_DIR, "sample_flow.csv")
    flow = pd.read_csv(flow_path)
    steps = flow.set_index("step")["n"].to_dict()

    fig, ax = plt.subplots(figsize=(4.0, 4.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 14)
    ax.axis("off")

    box_kw = dict(boxstyle="round,pad=0.35", facecolor="#DBEAFE", edgecolor="#2563EB", linewidth=0.8)
    excl_kw = dict(boxstyle="round,pad=0.25", facecolor="#FEF3C7", edgecolor="#D97706", linewidth=0.6)

    label_map = {
        "initial": "NHANES 2017\u20132023\nTotal participants",
        "age_18plus": "Age \u2265 18 years",
        "non_pregnant": "Non-pregnant",
        "has_fasting_glucose": "Fasting glucose available",
        "has_fasting_insulin": "Fasting insulin available",
        "valid_homa_labs": "Valid HOMA-IR labs",
    }
    reason_map = {
        "age_18plus": "Age < 18",
        "non_pregnant": "Pregnant",
        "has_fasting_glucose": "Missing fasting glucose",
        "has_fasting_insulin": "Missing fasting insulin",
        "valid_homa_labs": "Implausible fasting labs",
    }

    keys = list(steps.keys())
    vals = list(steps.values())
    n_steps = len(keys)
    y_start = 13
    y_gap = 2.5

    for i in range(n_steps):
        y = y_start - i * y_gap
        lbl = label_map.get(keys[i], keys[i].replace("_", " ").title())
        ax.text(4.0, y, f"{lbl}\nn = {vals[i]:,}", ha="center", va="center",
                fontsize=7.5, fontweight="bold", bbox=box_kw)
        if i > 0:
            ax.annotate("", xy=(4.0, y + 0.65), xytext=(4.0, y_start - (i - 1) * y_gap - 0.65),
                        arrowprops=dict(arrowstyle="-|>", lw=0.8, color="#2563EB"))
            excl = vals[i - 1] - vals[i]
            reason = reason_map.get(keys[i], "Excluded")
            ax.text(8.0, (y + y_start - (i - 1) * y_gap) / 2,
                    f"{reason}\nn = {excl:,}",
                    ha="center", va="center", fontsize=6.5, bbox=excl_kw)
            ax.annotate("", xy=(6.8, (y + y_start - (i - 1) * y_gap) / 2),
                        xytext=(5.5, y_start - (i - 1) * y_gap - 0.4),
                        arrowprops=dict(arrowstyle="-|>", lw=0.5, color="#D97706",
                                        connectionstyle="arc3,rad=-0.2"))

    plt.savefig(os.path.join(OUT_DIR, "fig1_consort_flow.png"))
    plt.close()
    print("  fig1 done")


# ── Figure 2: ROC Curves ──
def fig2(results):
    fig, ax = plt.subplots(figsize=(4.2, 3.8))
    order = ["FINDRISC", "ADA Risk Test", "Logistic Regression", "Random Forest",
             "SVM", "MLP", "LightGBM", "XGBoost"]
    for name in order:
        res = results.get(name)
        if not res or "fpr" not in res:
            continue
        fpr, tpr = np.array(res["fpr"]), np.array(res["tpr"])
        ci = ""
        if "auc_ci_lower" in res:
            ci = f" [{res['auc_ci_lower']:.3f}\u2013{res['auc_ci_upper']:.3f}]"
        ls = "--" if name in ("FINDRISC", "ADA Risk Test") else "-"
        lw = 0.9 if name in ("FINDRISC", "ADA Risk Test") else 1.4
        ax.plot(fpr, tpr, label=f"{name} ({res['auc']:.3f}{ci})",
                color=COLORS.get(name, "#333"), linestyle=ls, linewidth=lw)

    ax.plot([0, 1], [0, 1], "k:", linewidth=0.5, alpha=0.4)
    ax.set_xlabel("1 \u2013 Specificity (False Positive Rate)")
    ax.set_ylabel("Sensitivity (True Positive Rate)")
    ax.legend(loc="lower right", framealpha=0.92, edgecolor="#ccc", fontsize=6.5)
    ax.set_xlim([-0.01, 1.01])
    ax.set_ylim([-0.01, 1.01])
    ax.grid(True, alpha=0.15, linewidth=0.4)
    ax.set_aspect("equal")
    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "fig2_roc_curves.png"))
    plt.close()
    print("  fig2 done")


# ── Figure 3: SHAP Beeswarm ──
def fig3():
    sv = np.load(os.path.join(RESULTS_DIR, "shap_values.npy"))
    Xs = pd.read_parquet(os.path.join(RESULTS_DIR, "shap_X_sample.parquet"))
    Xd = Xs.rename(columns=FEAT_NAMES)

    fig, ax = plt.subplots(figsize=(5.0, 4.2))
    shap.summary_plot(sv, Xd, max_display=20, show=False, plot_size=None, color_bar=True)
    ax = plt.gca()
    ax.set_xlabel("SHAP value (impact on model output)", fontsize=8)
    ax.tick_params(axis="both", labelsize=7)
    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "fig3_shap_beeswarm.png"))
    plt.close()
    print("  fig3 done")


# ── Figure 4: Calibration Curves ──
def fig4():
    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    with open(os.path.join(DATA_PROCESSED_DIR, "features_used.txt")) as f:
        features = [l.strip() for l in f if l.strip()]
    features = [f for f in features if f in test.columns]
    y_test = test[BINARY_TARGET].values

    fig, ax = plt.subplots(figsize=(3.8, 3.5))
    models = {"Logistic Regression": ("logistic_regression", True),
              "Random Forest": ("random_forest", False),
              "XGBoost": ("xgboost", False),
              "LightGBM": ("lightgbm", False)}

    scaler_p = os.path.join(MODELS_DIR, "scaler.joblib")
    scaler = joblib.load(scaler_p) if os.path.exists(scaler_p) else None

    for dname, (fname, needs_sc) in models.items():
        mp = os.path.join(MODELS_DIR, f"{fname}.joblib")
        if not os.path.exists(mp):
            continue
        model = joblib.load(mp)
        X = test[features]
        Xi = scaler.transform(X) if needs_sc and scaler else X.values
        yp = model.predict_proba(Xi)[:, 1]
        pt, pp = calibration_curve(y_test, yp, n_bins=10, strategy="uniform")
        ax.plot(pp, pt, "o-", label=dname, color=COLORS[dname], markersize=3, linewidth=1.2)

    ax.plot([0, 1], [0, 1], "k--", linewidth=0.6, alpha=0.5)
    ax.set_xlabel("Mean predicted probability")
    ax.set_ylabel("Observed frequency")
    ax.legend(loc="upper left", fontsize=6.5, framealpha=0.9)
    ax.set_xlim([-0.02, 1.02]); ax.set_ylim([-0.02, 1.02])
    ax.grid(True, alpha=0.15, linewidth=0.4)
    ax.set_aspect("equal")
    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "fig4_calibration.png"))
    plt.close()
    print("  fig4 done")


# ── Figure 5: DCA ──
def fig5():
    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    with open(os.path.join(DATA_PROCESSED_DIR, "features_used.txt")) as f:
        features = [l.strip() for l in f if l.strip()]
    features = [f for f in features if f in test.columns]
    y = test[BINARY_TARGET].values
    prev = y.mean()
    thresholds = np.arange(0.01, 0.80, 0.01)

    fig, ax = plt.subplots(figsize=(3.8, 3.2))
    nb_all = prev - (1 - prev) * thresholds / (1 - thresholds)
    ax.plot(thresholds, nb_all, "k-", linewidth=0.7, alpha=0.5, label="Treat all")
    ax.axhline(0, color="gray", linewidth=0.4, linestyle="--", label="Treat none")

    models = {"XGBoost": ("xgboost", False), "LightGBM": ("lightgbm", False),
              "Logistic Regression": ("logistic_regression", True)}
    scaler_p = os.path.join(MODELS_DIR, "scaler.joblib")
    scaler = joblib.load(scaler_p) if os.path.exists(scaler_p) else None

    for dname, (fname, ns) in models.items():
        mp = os.path.join(MODELS_DIR, f"{fname}.joblib")
        if not os.path.exists(mp):
            continue
        model = joblib.load(mp)
        X = test[features]
        Xi = scaler.transform(X) if ns and scaler else X.values
        yp = model.predict_proba(Xi)[:, 1]
        nbs = []
        for t in thresholds:
            ypred = (yp >= t).astype(int)
            tp = np.sum((ypred == 1) & (y == 1))
            fp = np.sum((ypred == 1) & (y == 0))
            nbs.append(tp / len(y) - fp / len(y) * t / (1 - t))
        ax.plot(thresholds, nbs, label=dname, color=COLORS[dname], linewidth=1.3)

    ax.set_xlabel("Threshold probability")
    ax.set_ylabel("Net benefit")
    ax.legend(loc="upper right", fontsize=6.5, framealpha=0.9)
    ax.set_xlim([0, 0.75]); ax.set_ylim([-0.05, max(0.25, prev + 0.05)])
    ax.grid(True, alpha=0.15, linewidth=0.4)
    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "fig5_dca.png"))
    plt.close()
    print("  fig5 done")


# ── Figure 6: SHAP Dependence (2x2) ──
def fig6():
    sv = np.load(os.path.join(RESULTS_DIR, "shap_values.npy"))
    Xs = pd.read_parquet(os.path.join(RESULTS_DIR, "shap_X_sample.parquet"))
    imp = np.abs(sv).mean(axis=0)
    top4 = np.argsort(imp)[::-1][:4]

    fig, axes = plt.subplots(2, 2, figsize=(5.0, 4.2))
    for i, (idx, ax_) in enumerate(zip(top4, axes.flat)):
        feat = Xs.columns[idx]
        dn = FEAT_NAMES.get(feat, feat)
        sc = ax_.scatter(Xs.iloc[:, idx], sv[:, idx],
                         c=Xs.iloc[:, idx], cmap="coolwarm", alpha=0.3, s=2, rasterized=True)
        ax_.set_xlabel(dn, fontsize=7)
        ax_.set_ylabel("SHAP value", fontsize=7)
        ax_.axhline(0, color="gray", linewidth=0.3, linestyle="--")
        ax_.tick_params(labelsize=6)
        ax_.grid(True, alpha=0.1, linewidth=0.3)
    plt.tight_layout(h_pad=1.0, w_pad=0.8)
    plt.savefig(os.path.join(OUT_DIR, "fig6_shap_dependence.png"))
    plt.close()
    print("  fig6 done")


# ── Figure 7: Waterfall plots ──
def fig7():
    sv = np.load(os.path.join(RESULTS_DIR, "shap_values.npy"))
    Xs = pd.read_parquet(os.path.join(RESULTS_DIR, "shap_X_sample.parquet"))
    Xd = Xs.rename(columns=FEAT_NAMES)

    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    common = Xs.index.intersection(test.index)
    if len(common) == 0:
        print("  fig7 skipped (no common indices)")
        return

    y_sub = test.loc[common, BINARY_TARGET]
    idx_map = {i: ix for i, ix in enumerate(Xs.index) if ix in common}
    tp = [k for k, v in idx_map.items() if y_sub.get(v, -1) == 1]
    tn = [k for k, v in idx_map.items() if y_sub.get(v, -1) == 0]

    cases = []
    if tp: cases.append(("high_risk", tp[0]))
    if tn: cases.append(("low_risk", tn[0]))

    for tag, idx in cases:
        fig, ax = plt.subplots(figsize=(4.5, 3.5))
        expl = shap.Explanation(
            values=sv[idx], base_values=float(sv.mean()),
            data=Xd.iloc[idx].values, feature_names=Xd.columns.tolist(),
        )
        shap.plots.waterfall(expl, max_display=12, show=False)
        plt.tight_layout()
        plt.savefig(os.path.join(OUT_DIR, f"fig7_waterfall_{tag}.png"))
        plt.close()
        print(f"  fig7_{tag} done")


# ── Figure 8: Subgroup Forest Plot ──
def fig8(subgroup):
    fig, ax = plt.subplots(figsize=(4.5, 3.8))
    labels, aucs, los, his, ypos = [], [], [], [], []
    group_labels = {"age_group": "Age Group", "sex": "Sex",
                    "race": "Race/Ethnicity", "bmi_group": "BMI Category"}
    pos = 0
    for grp in ["age_group", "sex", "race", "bmi_group"]:
        if grp not in subgroup:
            continue
        labels.append(group_labels.get(grp, grp))
        aucs.append(None); los.append(None); his.append(None)
        ypos.append(pos); pos += 1
        for lbl, vals in subgroup[grp].items():
            labels.append(f"  {lbl} (n={vals['n']:,})")
            aucs.append(vals["auc"]); los.append(vals["auc_ci_lower"]); his.append(vals["auc_ci_upper"])
            ypos.append(pos); pos += 1
        pos += 0.3

    for i in range(len(labels)):
        if aucs[i] is None:
            ax.text(0.52, ypos[i], labels[i], va="center", fontsize=7.5, fontweight="bold")
        else:
            ax.errorbar(aucs[i], ypos[i],
                        xerr=[[aucs[i] - los[i]], [his[i] - aucs[i]]],
                        fmt="s", color="#2563EB", markersize=4, capsize=2, linewidth=0.8,
                        markerfacecolor="#2563EB", markeredgecolor="#2563EB")
            ax.text(0.52, ypos[i], labels[i], va="center", fontsize=6.5)

    ax.set_xlabel("AUC (95% CI)")
    ax.invert_yaxis()
    ax.axvline(0.5, color="#ccc", linestyle="--", linewidth=0.4)
    ax.axvline(0.8, color="#ccc", linestyle=":", linewidth=0.3)
    ax.set_xlim([0.50, 0.90])
    ax.set_yticks([])
    ax.grid(True, axis="x", alpha=0.15, linewidth=0.3)
    ax.spines["left"].set_visible(False)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "fig8_subgroup_forest.png"))
    plt.close()
    print("  fig8 done")


# ── Combined: Calibration + DCA side-by-side ──
def fig_cal_dca_combined():
    test = pd.read_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"))
    with open(os.path.join(DATA_PROCESSED_DIR, "features_used.txt")) as f:
        features = [l.strip() for l in f if l.strip()]
    features = [f for f in features if f in test.columns]
    y = test[BINARY_TARGET].values
    prev = y.mean()

    scaler_p = os.path.join(MODELS_DIR, "scaler.joblib")
    scaler = joblib.load(scaler_p) if os.path.exists(scaler_p) else None

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(6.8, 3.0))

    # Left: Calibration
    models_cal = {"Logistic Regression": ("logistic_regression", True),
                  "Random Forest": ("random_forest", False),
                  "XGBoost": ("xgboost", False),
                  "LightGBM": ("lightgbm", False)}
    for dname, (fname, ns) in models_cal.items():
        mp = os.path.join(MODELS_DIR, f"{fname}.joblib")
        if not os.path.exists(mp): continue
        model = joblib.load(mp)
        X = test[features]
        Xi = scaler.transform(X) if ns and scaler else X.values
        yp = model.predict_proba(Xi)[:, 1]
        pt, pp = calibration_curve(y, yp, n_bins=10, strategy="uniform")
        ax1.plot(pp, pt, "o-", label=dname, color=COLORS[dname], markersize=2.5, linewidth=1.0)
    ax1.plot([0, 1], [0, 1], "k--", linewidth=0.5, alpha=0.5)
    ax1.set_xlabel("Mean predicted probability")
    ax1.set_ylabel("Observed frequency")
    ax1.legend(fontsize=5.5, framealpha=0.9, loc="upper left")
    ax1.set_xlim([-0.02, 1.02]); ax1.set_ylim([-0.02, 1.02])
    ax1.grid(True, alpha=0.12, linewidth=0.3)
    ax1.set_aspect("equal")
    ax1.text(-0.15, 1.05, "(a)", transform=ax1.transAxes, fontsize=9, fontweight="bold")

    # Right: DCA
    thresholds = np.arange(0.01, 0.75, 0.01)
    nb_all = prev - (1 - prev) * thresholds / (1 - thresholds)
    ax2.plot(thresholds, nb_all, "k-", linewidth=0.6, alpha=0.4, label="Treat all")
    ax2.axhline(0, color="gray", linewidth=0.3, linestyle="--", label="Treat none")
    models_dca = {"XGBoost": ("xgboost", False), "LightGBM": ("lightgbm", False),
                  "Logistic Regression": ("logistic_regression", True)}
    for dname, (fname, ns) in models_dca.items():
        mp = os.path.join(MODELS_DIR, f"{fname}.joblib")
        if not os.path.exists(mp): continue
        model = joblib.load(mp)
        X = test[features]
        Xi = scaler.transform(X) if ns and scaler else X.values
        yp = model.predict_proba(Xi)[:, 1]
        nbs = []
        for t in thresholds:
            ypred = (yp >= t).astype(int)
            tp_n = np.sum((ypred == 1) & (y == 1))
            fp_n = np.sum((ypred == 1) & (y == 0))
            nbs.append(tp_n / len(y) - fp_n / len(y) * t / (1 - t))
        ax2.plot(thresholds, nbs, label=dname, color=COLORS[dname], linewidth=1.1)
    ax2.set_xlabel("Threshold probability")
    ax2.set_ylabel("Net benefit")
    ax2.legend(fontsize=5.5, framealpha=0.9, loc="upper right")
    ax2.set_xlim([0, 0.72]); ax2.set_ylim([-0.05, max(0.28, prev + 0.03)])
    ax2.grid(True, alpha=0.12, linewidth=0.3)
    ax2.text(-0.15, 1.05, "(b)", transform=ax2.transAxes, fontsize=9, fontweight="bold")

    plt.tight_layout(w_pad=1.5)
    plt.savefig(os.path.join(OUT_DIR, "fig_cal_dca.png"))
    plt.close()
    print("  fig_cal_dca done")


# ── Main ──
if __name__ == "__main__":
    print("Regenerating all figures...")
    results, subgroup = load_all()
    fig1()
    fig2(results)
    fig3()
    fig4()
    fig5()
    fig6()
    fig7()
    fig8(subgroup)
    fig_cal_dca_combined()
    print("All figures saved to", OUT_DIR)
