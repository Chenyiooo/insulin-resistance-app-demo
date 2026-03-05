"""
Step 2: Build the analytic dataset from downloaded NHANES XPT files.
- Read and harmonize variables across cycles
- Merge files within each cycle on SEQN
- Apply inclusion/exclusion criteria
- Define outcome variable (HbA1c-based)
- Engineer features
- Impute missing values
- Save train/test splits
"""
import os
import warnings
import numpy as np
import pandas as pd
import pyreadstat
from sklearn.experimental import enable_iterative_imputer  # noqa
from sklearn.impute import IterativeImputer
from config import (
    CYCLES, COMPONENT_BASES, DATA_RAW_DIR, DATA_PROCESSED_DIR,
    get_file_url, get_alternative_urls, VAR_HARMONIZE,
    PREDICTOR_FEATURES, BINARY_TARGET, MULTICLASS_TARGET,
    FILE_NAME_OVERRIDES, RANDOM_STATE,
)

warnings.filterwarnings("ignore")


# ── Reading XPT files ──

def find_xpt_file(component, cycle):
    """Find the local XPT file for a component/cycle, checking alternatives."""
    cycle_dir = os.path.join(DATA_RAW_DIR, cycle["name"])

    _, primary_name = get_file_url(component, cycle)
    primary_path = os.path.join(cycle_dir, f"{primary_name}.XPT")
    if os.path.exists(primary_path):
        return primary_path

    for _, alt_name in get_alternative_urls(component, cycle):
        alt_path = os.path.join(cycle_dir, f"{alt_name}.XPT")
        if os.path.exists(alt_path):
            return alt_path

    # Brute-force search in the directory
    if os.path.isdir(cycle_dir):
        for f in os.listdir(cycle_dir):
            if f.upper().endswith(".XPT") and component.upper() in f.upper():
                return os.path.join(cycle_dir, f)

    return None


def read_xpt(filepath):
    """Read a SAS XPT file, trying pyreadstat first, then pandas."""
    try:
        df, _ = pyreadstat.read_xport(filepath)
        return df
    except Exception:
        try:
            return pd.read_sas(filepath, format="xport", encoding="utf-8")
        except Exception as e:
            print(f"    [ERROR] Cannot read {filepath}: {e}")
            return None


def harmonize_variables(df, mapping):
    """Rename columns based on the harmonization mapping.
    For each standard name, find the first matching raw variable in the dataframe.
    """
    rename_map = {}
    for std_name, raw_names in mapping.items():
        for raw in raw_names:
            if raw in df.columns:
                rename_map[raw] = std_name
                break
    return df.rename(columns=rename_map)


# ── Load & merge a single cycle ──

def load_cycle(cycle):
    """Load all component files for one cycle, merge on SEQN."""
    cycle_name = cycle["name"]
    print(f"\n  Loading cycle {cycle_name}...")

    merged = None
    for comp in COMPONENT_BASES:
        filepath = find_xpt_file(comp, cycle)
        if filepath is None:
            print(f"    {comp:6s}: not found (skipping)")
            continue

        df = read_xpt(filepath)
        if df is None or df.empty:
            continue

        if "SEQN" not in df.columns:
            print(f"    {comp:6s}: no SEQN column (skipping)")
            continue

        df = harmonize_variables(df, VAR_HARMONIZE)
        df["SEQN"] = df["SEQN"].astype(int)

        # Keep only harmonized columns + SEQN
        std_cols = set(VAR_HARMONIZE.keys())
        keep_cols = ["SEQN"] + [c for c in df.columns if c in std_cols]
        df = df[keep_cols]

        if merged is None:
            merged = df
        else:
            new_cols = [c for c in df.columns if c not in merged.columns or c == "SEQN"]
            if len(new_cols) > 1:
                merged = merged.merge(df[new_cols], on="SEQN", how="outer")

        n_vars = len([c for c in df.columns if c in std_cols])
        print(f"    {comp:6s}: {len(df):>6d} rows, {n_vars} harmonized vars")

    if merged is not None:
        merged["cycle"] = cycle_name
        merged["split"] = cycle["split"]
        print(f"    -> Merged: {len(merged)} rows")

    return merged


# ── Apply inclusion/exclusion criteria ──

def apply_criteria(df):
    """Apply study inclusion/exclusion criteria."""
    flow = {"initial": len(df)}

    # Must be 18+
    df = df[df["age"] >= 18].copy()
    flow["age_18plus"] = len(df)

    # Exclude pregnant
    if "pregnant" in df.columns:
        df = df[~(df["pregnant"] == 1)].copy()
    flow["non_pregnant"] = len(df)

    # Must have HbA1c
    df = df[df["hba1c"].notna()].copy()
    flow["has_hba1c"] = len(df)

    # Exclude extreme/implausible HbA1c (< 3% or > 20%)
    df = df[(df["hba1c"] >= 3.0) & (df["hba1c"] <= 20.0)].copy()
    flow["valid_hba1c"] = len(df)

    return df, flow


# ── Define outcome variables ──

def define_outcomes(df):
    """Create diabetes outcome variables based on HbA1c and self-report."""
    # Three-class: 0=normal, 1=prediabetes, 2=diabetes
    conditions = [
        df["hba1c"] < 5.7,
        (df["hba1c"] >= 5.7) & (df["hba1c"] < 6.5),
        df["hba1c"] >= 6.5,
    ]
    df[MULTICLASS_TARGET] = np.select(conditions, [0, 1, 2], default=np.nan)

    # Also mark self-reported diabetes as diabetes
    if "diabetes_self_report" in df.columns:
        df.loc[df["diabetes_self_report"] == 1, MULTICLASS_TARGET] = 2

    # Binary: 0=normal, 1=at-risk (prediabetes + diabetes)
    df[BINARY_TARGET] = (df[MULTICLASS_TARGET] >= 1).astype(int)

    return df


# ── Feature engineering ──

def engineer_features(df):
    """Create derived features."""
    # Smoking status: 0=never, 1=former, 2=current
    df["smoking_status"] = 0  # never
    mask_ever = df["smoked_100"] == 1
    mask_current = df["smoke_now"].isin([1, 2])  # every day or some days
    df.loc[mask_ever & ~mask_current, "smoking_status"] = 1  # former
    df.loc[mask_ever & mask_current, "smoking_status"] = 2   # current

    # PHQ-9 total score
    phq9_cols = [f"phq9_{i}" for i in range(1, 10)]
    existing_phq9 = [c for c in phq9_cols if c in df.columns]
    if existing_phq9:
        df["phq9_score"] = df[existing_phq9].sum(axis=1, min_count=5)
    else:
        df["phq9_score"] = np.nan

    # Weight change percent (current vs 10 years ago)
    if "weight_10yr_ago" in df.columns and "weight" in df.columns:
        valid = (df["weight_10yr_ago"] > 20) & (df["weight"] > 20)
        df.loc[valid, "weight_change_pct"] = (
            (df.loc[valid, "weight"] - df.loc[valid, "weight_10yr_ago"])
            / df.loc[valid, "weight_10yr_ago"] * 100
        )
    else:
        df["weight_change_pct"] = np.nan

    # Waist-to-height ratio
    if "waist_circumference" in df.columns and "height" in df.columns:
        valid = (df["height"] > 0) & (df["waist_circumference"] > 0)
        df.loc[valid, "waist_height_ratio"] = (
            df.loc[valid, "waist_circumference"] / df.loc[valid, "height"]
        )
    else:
        df["waist_height_ratio"] = np.nan

    # Recode binary variables (NHANES uses 1=Yes, 2=No -> 1/0)
    binary_recode = [
        "family_diabetes", "hypertension_history", "hypertension_med",
        "high_cholesterol", "gestational_diabetes", "macrosomia",
        "vigorous_work", "moderate_work", "vigorous_recreation", "moderate_recreation",
        "sleep_trouble",
    ]
    for col in binary_recode:
        if col in df.columns:
            df[col] = df[col].map({1: 1, 2: 0}).where(df[col].isin([1, 2]))

    # Alcohol: simplify frequency to drinks per week (approximate)
    if "alcohol_frequency" in df.columns:
        freq_map = {
            0: 0, 1: 365, 2: 312, 3: 208, 4: 104, 5: 52,
            6: 24, 7: 12, 8: 6, 9: 3, 10: 0,
        }
        df["alcohol_days_per_year"] = df["alcohol_frequency"].map(freq_map)
    else:
        df["alcohol_days_per_year"] = np.nan

    return df


# ── Clean features ──

def clean_features(df):
    """Clean and validate feature ranges, cap outliers."""
    caps = {
        "bmi": (10, 80),
        "waist_circumference": (40, 200),
        "weight": (20, 300),
        "height": (100, 220),
        "systolic_bp": (60, 260),
        "diastolic_bp": (20, 160),
        "pulse": (30, 180),
        "sedentary_minutes": (0, 1440),
        "sleep_hours": (1, 20),
        "phq9_score": (0, 27),
        "weight_change_pct": (-80, 200),
        "income_ratio": (0, 5),
    }
    for col, (lo, hi) in caps.items():
        if col in df.columns:
            df.loc[df[col] < lo, col] = np.nan
            df.loc[df[col] > hi, col] = np.nan

    return df


# ── Imputation ──

def impute_missing(df, features):
    """Impute missing values using iterative imputer (MICE-like) for numeric,
    mode for categorical. Fit on train split, transform both."""
    from sklearn.model_selection import train_test_split

    numeric_feats = df[features].select_dtypes(include=[np.number]).columns.tolist()
    cat_feats = [f for f in features if f not in numeric_feats and f in df.columns]

    for col in cat_feats:
        if col in df.columns and df[col].isna().any():
            mode_val = df[col].mode()
            if len(mode_val) > 0:
                df[col] = df[col].fillna(mode_val.iloc[0])

    existing_numeric = [f for f in numeric_feats if f in df.columns]
    if existing_numeric:
        train_mask = df["split"] == "train"
        imputer = IterativeImputer(
            max_iter=10, random_state=RANDOM_STATE, sample_posterior=False
        )
        df.loc[train_mask, existing_numeric] = imputer.fit_transform(
            df.loc[train_mask, existing_numeric]
        )
        df.loc[~train_mask, existing_numeric] = imputer.transform(
            df.loc[~train_mask, existing_numeric]
        )

    return df


# ── Main pipeline ──

def build_dataset():
    """Run the complete dataset building pipeline."""
    print("=" * 60)
    print("  Building NHANES Analytic Dataset")
    print("=" * 60)

    # 1. Load and merge all cycles
    all_cycles = []
    for cycle in CYCLES:
        df = load_cycle(cycle)
        if df is not None:
            all_cycles.append(df)

    if not all_cycles:
        raise RuntimeError("No data loaded. Run 01_download_data.py first.")

    combined = pd.concat(all_cycles, ignore_index=True)
    print(f"\n  Combined raw data: {len(combined)} rows")

    # 2. Apply inclusion/exclusion criteria
    combined, flow = apply_criteria(combined)
    print(f"\n  Sample flow:")
    for step, n in flow.items():
        print(f"    {step:20s}: {n:>6d}")

    # Save flow for CONSORT diagram
    flow_df = pd.DataFrame(list(flow.items()), columns=["step", "n"])
    os.makedirs(DATA_PROCESSED_DIR, exist_ok=True)
    flow_df.to_csv(os.path.join(DATA_PROCESSED_DIR, "sample_flow.csv"), index=False)

    # 3. Define outcomes
    combined = define_outcomes(combined)

    # 4. Feature engineering
    combined = engineer_features(combined)
    combined = clean_features(combined)

    # 5. Report missing rates
    features_available = [f for f in PREDICTOR_FEATURES if f in combined.columns]
    missing_pct = combined[features_available].isna().mean() * 100
    print(f"\n  Missing rates (top 10):")
    for col, pct in missing_pct.sort_values(ascending=False).head(10).items():
        print(f"    {col:30s}: {pct:.1f}%")

    missing_df = missing_pct.reset_index()
    missing_df.columns = ["feature", "missing_pct"]
    missing_df.to_csv(os.path.join(DATA_PROCESSED_DIR, "missing_rates.csv"), index=False)

    # 6. Random 80:20 split (stratified by outcome)
    from sklearn.model_selection import train_test_split
    print(f"\n  Splitting data 80:20 (stratified, random_state={RANDOM_STATE})...")
    train_idx, test_idx = train_test_split(
        combined.index, test_size=0.2, random_state=RANDOM_STATE,
        stratify=combined[BINARY_TARGET],
    )
    combined.loc[train_idx, "split"] = "train"
    combined.loc[test_idx, "split"] = "test"

    # 7. Impute missing values (fit on train, transform both)
    print(f"  Imputing missing values (MICE)...")
    combined = impute_missing(combined, features_available)

    # 8. Save
    train = combined[combined["split"] == "train"].copy()
    test = combined[combined["split"] == "test"].copy()

    print(f"\n  Train set: {len(train)} ({train[BINARY_TARGET].mean():.1%} positive)")
    print(f"  Test set:  {len(test)} ({test[BINARY_TARGET].mean():.1%} positive)")

    # Class distribution
    for name, subset in [("Train", train), ("Test", test)]:
        dist = subset[MULTICLASS_TARGET].value_counts().sort_index()
        print(f"\n  {name} class distribution:")
        labels = {0: "Normal", 1: "Prediabetes", 2: "Diabetes"}
        for cls, count in dist.items():
            print(f"    {labels.get(cls, cls):15s}: {count:>6d} ({count/len(subset):.1%})")

    combined.to_parquet(os.path.join(DATA_PROCESSED_DIR, "full_dataset.parquet"), index=False)
    train.to_parquet(os.path.join(DATA_PROCESSED_DIR, "train.parquet"), index=False)
    test.to_parquet(os.path.join(DATA_PROCESSED_DIR, "test.parquet"), index=False)

    # Save feature list actually used
    with open(os.path.join(DATA_PROCESSED_DIR, "features_used.txt"), "w") as f:
        for feat in features_available:
            f.write(feat + "\n")

    print(f"\n  Datasets saved to {DATA_PROCESSED_DIR}")
    return combined, flow


if __name__ == "__main__":
    build_dataset()
