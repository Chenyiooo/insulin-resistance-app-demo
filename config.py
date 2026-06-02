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
    "DR1TOT": "DR1TOT",
    "DR2TOT": "DR2TOT",
    "DSQTOT": "DSQTOT",
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


DIETARY_NUTRIENTS = {
    "energy_kcal": "Energy (kcal)",
    "protein_g": "Protein (gm)",
    "carb_g": "Carbohydrate (gm)",
    "sugar_g": "Total sugars (gm)",
    "fiber_g": "Dietary fiber (gm)",
    "total_fat_g": "Total fat (gm)",
    "sat_fat_g": "Total saturated fatty acids (gm)",
    "mono_fat_g": "Total monounsaturated fatty acids (gm)",
    "poly_fat_g": "Total polyunsaturated fatty acids (gm)",
    "cholesterol_mg": "Cholesterol (mg)",
    "sodium_mg": "Sodium (mg)",
    "potassium_mg": "Potassium (mg)",
    "calcium_mg": "Calcium (mg)",
    "magnesium_mg": "Magnesium (mg)",
    "vitamin_d_mcg": "Vitamin D (D2 + D3) (mcg)",
    "caffeine_mg": "Caffeine (mg)",
    "alcohol_g": "Alcohol (gm)",
}


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

    # Dietary recall metadata
    "diet_recall_days": ["DRDINT"],
    "diet_day1_recall_status": ["DR1DRSTZ"],
    "diet_day2_recall_status": ["DR2DRSTZ"],

    # Total nutrient intakes from foods/beverages, first 24-hour recall
    "diet_day1_energy_kcal": ["DR1TKCAL"],
    "diet_day1_protein_g": ["DR1TPROT"],
    "diet_day1_carb_g": ["DR1TCARB"],
    "diet_day1_sugar_g": ["DR1TSUGR"],
    "diet_day1_fiber_g": ["DR1TFIBE"],
    "diet_day1_total_fat_g": ["DR1TTFAT"],
    "diet_day1_sat_fat_g": ["DR1TSFAT"],
    "diet_day1_mono_fat_g": ["DR1TMFAT"],
    "diet_day1_poly_fat_g": ["DR1TPFAT"],
    "diet_day1_cholesterol_mg": ["DR1TCHOL"],
    "diet_day1_sodium_mg": ["DR1TSODI"],
    "diet_day1_potassium_mg": ["DR1TPOTA"],
    "diet_day1_calcium_mg": ["DR1TCALC"],
    "diet_day1_magnesium_mg": ["DR1TMAGN"],
    "diet_day1_vitamin_d_mcg": ["DR1TVD"],
    "diet_day1_caffeine_mg": ["DR1TCAFF"],
    "diet_day1_alcohol_g": ["DR1TALCO"],

    # Total nutrient intakes from foods/beverages, second 24-hour recall
    "diet_day2_energy_kcal": ["DR2TKCAL"],
    "diet_day2_protein_g": ["DR2TPROT"],
    "diet_day2_carb_g": ["DR2TCARB"],
    "diet_day2_sugar_g": ["DR2TSUGR"],
    "diet_day2_fiber_g": ["DR2TFIBE"],
    "diet_day2_total_fat_g": ["DR2TTFAT"],
    "diet_day2_sat_fat_g": ["DR2TSFAT"],
    "diet_day2_mono_fat_g": ["DR2TMFAT"],
    "diet_day2_poly_fat_g": ["DR2TPFAT"],
    "diet_day2_cholesterol_mg": ["DR2TCHOL"],
    "diet_day2_sodium_mg": ["DR2TSODI"],
    "diet_day2_potassium_mg": ["DR2TPOTA"],
    "diet_day2_calcium_mg": ["DR2TCALC"],
    "diet_day2_magnesium_mg": ["DR2TMAGN"],
    "diet_day2_vitamin_d_mcg": ["DR2TVD"],
    "diet_day2_caffeine_mg": ["DR2TCAFF"],
    "diet_day2_alcohol_g": ["DR2TALCO"],

    # Mean daily nutrient intakes from dietary supplements/antacids over 30 days
    "supplement_used": ["DSD010"],
    "supplement_count": ["DSDCOUNT"],
    "antacid_used": ["DSD010AN"],
    "antacid_count": ["DSDANCNT"],
    "supp_energy_kcal": ["DSQTKCAL"],
    "supp_protein_g": ["DSQTPROT"],
    "supp_carb_g": ["DSQTCARB"],
    "supp_sugar_g": ["DSQTSUGR"],
    "supp_fiber_g": ["DSQTFIBE"],
    "supp_total_fat_g": ["DSQTTFAT"],
    "supp_sat_fat_g": ["DSQTSFAT"],
    "supp_mono_fat_g": ["DSQTMFAT"],
    "supp_poly_fat_g": ["DSQTPFAT"],
    "supp_cholesterol_mg": ["DSQTCHOL"],
    "supp_sodium_mg": ["DSQTSODI"],
    "supp_potassium_mg": ["DSQTPOTA"],
    "supp_calcium_mg": ["DSQTCALC"],
    "supp_magnesium_mg": ["DSQTMAGN"],
    "supp_vitamin_d_mcg": ["DSQTVD"],
    "supp_caffeine_mg": ["DSQTCAFF"],

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
