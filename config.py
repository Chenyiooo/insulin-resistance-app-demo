"""
Configuration for NHANES-based Diabetes Risk Screening Project.
All cycle definitions, file mappings, variable harmonizations, and model settings.
"""
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_RAW_DIR = os.path.join(BASE_DIR, "data", "raw")
DATA_PROCESSED_DIR = os.path.join(BASE_DIR, "data", "processed")
RESULTS_DIR = os.path.join(BASE_DIR, "results")
FIGURES_DIR = os.path.join(RESULTS_DIR, "figures")
TABLES_DIR = os.path.join(RESULTS_DIR, "tables")
MODELS_DIR = os.path.join(RESULTS_DIR, "models")

NHANES_BASE_URL = "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public"

RANDOM_STATE = 42

# ── NHANES cycle definitions ──
# Using recent cycles (2017-2023) only; data will be randomly split 80:20.
# 'start_year' is used in the new CDC URL: .../Public/{start_year}/DataFiles/
CYCLES = [
    {"name": "2017-2020", "start_year": "2017", "suffix": "",   "split": "all", "prefix": "P_"},
    {"name": "2021-2023", "start_year": "2021", "suffix": "_L", "split": "all"},
]

# ── NHANES file name mappings ──
# Maps (component, cycle_name) -> filename (without .XPT)
# Most follow the pattern: COMPONENT{suffix} or P_COMPONENT for pre-pandemic
COMPONENT_BASES = {
    "DEMO": "DEMO",
    "BMX": "BMX",
    "BPX": "BPX",
    "DIQ": "DIQ",
    "MCQ": "MCQ",
    "BPQ": "BPQ",
    "SMQ": "SMQ",
    "ALQ": "ALQ",
    "PAQ": "PAQ",
    "SLQ": "SLQ",
    "DPQ": "DPQ",
    "RHQ": "RHQ",
    "WHQ": "WHQ",
    "GHB": "GHB",
}

# Overrides for cycles where file names deviate from pattern
FILE_NAME_OVERRIDES = {
    ("BPX", "2017-2020"): "P_BPXO",
    ("BPX", "2021-2023"): "BPXO_L",
}

# Alternative file names to try if primary fails
FILE_NAME_ALTERNATIVES = {}

# Components that might not exist in all cycles
OPTIONAL_COMPONENTS = {"DPQ", "SLQ", "WHQ", "RHQ"}


def get_file_url(component, cycle):
    """Build the download URL for a given NHANES component and cycle.
    New CDC URL format: .../Public/{start_year}/DataFiles/{filename}.xpt
    """
    cycle_name = cycle["name"]
    year = cycle["start_year"]

    key = (component, cycle_name)
    if key in FILE_NAME_OVERRIDES:
        filename = FILE_NAME_OVERRIDES[key]
    elif cycle.get("prefix"):
        filename = f"{cycle['prefix']}{COMPONENT_BASES[component]}"
    else:
        filename = f"{COMPONENT_BASES[component]}{cycle['suffix']}"

    return f"{NHANES_BASE_URL}/{year}/DataFiles/{filename}.xpt", filename


def get_alternative_urls(component, cycle):
    """Return alternative URLs to try if the primary URL fails."""
    key = (component, cycle["name"])
    year = cycle["start_year"]
    alternatives = FILE_NAME_ALTERNATIVES.get(key, [])
    return [(f"{NHANES_BASE_URL}/{year}/DataFiles/{alt}.xpt", alt) for alt in alternatives]


# ── Variable harmonization ──
# Maps raw NHANES variable names to standardized names
# The harmonizer tries each alternative in order

VAR_HARMONIZE = {
    # Demographics
    "age":          ["RIDAGEYR"],
    "sex":          ["RIAGENDR"],
    "race":         ["RIDRETH1"],
    "education":    ["DMDEDUC2"],
    "income_ratio": ["INDFMPIR"],
    "pregnant":     ["RIDEXPRG"],

    # Body Measures
    "bmi":                ["BMXBMI"],
    "waist_circumference": ["BMXWAIST"],
    "weight":             ["BMXWT"],
    "height":             ["BMXHT"],
    "arm_circumference":  ["BMXARMC"],

    # Blood Pressure (oscillometric vars first for newer cycles)
    "systolic_bp":  ["BPXOSY1", "BPXSY1"],
    "diastolic_bp": ["BPXODI1", "BPXDI1"],
    "pulse":        ["BPXOPLS", "BPXPLS"],

    # Glycohemoglobin
    "hba1c": ["LBXGH"],

    # Diabetes questionnaire
    "diabetes_self_report": ["DIQ010"],

    # Medical history
    "family_diabetes":       ["MCQ300C"],
    "hypertension_history":  ["BPQ020"],
    "hypertension_med":      ["BPQ040A"],
    "high_cholesterol":      ["BPQ080"],

    # Smoking
    "smoked_100":    ["SMQ020"],
    "smoke_now":     ["SMQ040"],

    # Alcohol
    "alcohol_12_drinks": ["ALQ101", "ALQ110", "ALQ100"],
    "alcohol_frequency": ["ALQ121", "ALQ120Q"],
    "alcohol_avg_drinks": ["ALQ130"],

    # Physical activity (GPAQ, available 2007+)
    "vigorous_work":      ["PAQ605"],
    "moderate_work":      ["PAQ620"],
    "vigorous_recreation": ["PAQ650"],
    "moderate_recreation": ["PAQ665"],
    "sedentary_minutes":  ["PAD680"],

    # Sleep
    "sleep_hours":   ["SLD012", "SLD010H"],
    "sleep_trouble": ["SLQ060", "SLQ050"],

    # Depression (PHQ-9), 2005+
    "phq9_1": ["DPQ010"], "phq9_2": ["DPQ020"], "phq9_3": ["DPQ030"],
    "phq9_4": ["DPQ040"], "phq9_5": ["DPQ050"], "phq9_6": ["DPQ060"],
    "phq9_7": ["DPQ070"], "phq9_8": ["DPQ080"], "phq9_9": ["DPQ090"],

    # Reproductive health (females)
    "gestational_diabetes": ["RHQ162", "RHD162", "RHQ160"],
    "macrosomia":           ["RHQ172", "RHD172", "RHQ171"],

    # Weight history
    "weight_10yr_ago":      ["WHD110"],
    "self_reported_weight": ["WHD020"],
}

# ── Feature groups for the final model ──
PREDICTOR_FEATURES = [
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
]

BINARY_TARGET = "diabetes_binary"      # 0=normal, 1=prediabetes+diabetes
MULTICLASS_TARGET = "diabetes_status"  # 0=normal, 1=prediabetes, 2=diabetes

# ── Age/Sex/Race subgroups for fairness analysis ──
SUBGROUPS = {
    "age_group": {
        "18-39": lambda df: (df["age"] >= 18) & (df["age"] < 40),
        "40-59": lambda df: (df["age"] >= 40) & (df["age"] < 60),
        "60+":   lambda df: df["age"] >= 60,
    },
    "sex": {
        "Male":   lambda df: df["sex"] == 1,
        "Female": lambda df: df["sex"] == 2,
    },
    "race": {
        "NH White":  lambda df: df["race"] == 3,
        "NH Black":  lambda df: df["race"] == 4,
        "Hispanic":  lambda df: df["race"].isin([1, 2]),
        "Other":     lambda df: df["race"] == 5,
    },
    "bmi_group": {
        "Normal (<25)":     lambda df: df["bmi"] < 25,
        "Overweight (25-30)": lambda df: (df["bmi"] >= 25) & (df["bmi"] < 30),
        "Obese (≥30)":      lambda df: df["bmi"] >= 30,
    },
}
