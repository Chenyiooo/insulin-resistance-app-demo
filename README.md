# Beyond the Blood Draw

**Explainable Machine Learning for Non-Invasive Insulin Resistance Screening**

This repository contains the full reproducible pipeline for the paper:

> Black Sun\*, Chenyi Zhang\*, Xi Lu. *Beyond the Blood Draw: Explainable Machine Learning for Non-Invasive Type 2 Diabetes Risk Screening.* AMIA 2026 Annual Symposium.

## Overview

We develop and validate machine learning models for insulin resistance screening using a reduced **18-feature low-burden LightGBM model** from the National Health and Nutrition Examination Survey (NHANES) 2017--2023. The reduced input set was selected from the restored 67-feature baseline using predictive value, calibration/FNR, user burden, measurement reliability, clinical validity, and subgroup behavior. The learning target is lab-defined insulin resistance from HOMA-IR.

The HOMA-IR label is calculated from fasting glucose and insulin:

```text
HOMA-IR = LBDGLUSI (mmol/L) * LBXIN (mIU/L) / 22.5
insulin_resistance_binary = 1 if HOMA-IR > 2.5
```

`LBDGLUSI`, `LBXIN`, and `homa_ir` are used only to define the target and are not included as model inputs.

**Current reduced LightGBM result:**
- Reduced 18-feature LightGBM AUC = 0.8434, AUPRC = 0.8377, FNR = 0.2169
- Restored 67-feature LightGBM baseline AUC = 0.8514
- The reduced model removes detailed diet nutrients and supplement nutrient estimates from the required flow

## Repository Structure

```
├── config.py                  # Central configuration (cycles, features, models)
├── 01_download_data.py        # Download NHANES XPT files from CDC
├── 02_build_dataset.py        # Process raw data, apply inclusion criteria, impute, split
├── 03_train_and_evaluate.py   # Train models, evaluate, SHAP, subgroup analysis
├── 04_generate_figures.py     # Generate initial figures
├── 05_regen_figures.py        # Regenerate publication-quality figures
├── run_pipeline.py            # Run the full pipeline end-to-end
├── requirements.txt           # Python dependencies
├── features_used.txt          # Current default model feature list
├── data/
│   ├── raw/                   # Downloaded NHANES XPT files (not tracked)
│   └── processed/             # Processed parquet files + metadata
├── results/
│   ├── models/                # Trained model files (.joblib)
│   ├── tables/                # CSV result tables
│   ├── all_results.json       # Full model evaluation metrics
│   └── subgroup_results.json  # Subgroup fairness analysis
└── paper/
    ├── amia.tex               # LaTeX manuscript
    ├── amia.bib               # BibTeX references
    ├── amia.cls               # AMIA document class
    └── figures/               # Publication figures (PNG)
```

## Quick Start

### 1. Install dependencies

```bash
pip install -r requirements.txt
```

Python 3.9+ is required.

### 2. Run the full pipeline

```bash
python run_pipeline.py
```

This will:
1. Download NHANES 2017--2023 data from CDC (~200 MB)
2. Build the analytic dataset (n=14,352) with 80:20 stratified split
3. Train 6 ML models + compute 2 traditional risk scores
4. Run SHAP explainability and subgroup fairness analysis
5. Generate all figures

Alternatively, run each step individually:

```bash
python 01_download_data.py
python 02_build_dataset.py
python 03_train_and_evaluate.py
python 05_regen_figures.py
```

### 3. Compile the paper

```bash
cd paper
pdflatex amia.tex
bibtex amia
pdflatex amia.tex
pdflatex amia.tex
```

## Data

All data are publicly available from the [CDC NHANES website](https://wwwn.cdc.gov/nchs/nhanes/). The download script (`01_download_data.py`) fetches the required XPT files automatically. Two NHANES cycles are used:

| Cycle | Period | N (raw) |
|-------|--------|---------|
| 2017--2020 | Pre-pandemic | ~15,500 |
| 2021--2023 | Post-pandemic | ~12,000 |

After applying inclusion criteria (age >= 18, non-pregnant, valid fasting glucose and insulin), the analytic sample is restricted to participants with enough fasting laboratory data to calculate HOMA-IR.

## Reduced LightGBM Model

The active model is trained with LightGBM only. Other model families are not part of the reduced production workflow.

| Model | Features | AUC | AUPRC | Sensitivity | Specificity | FNR | Brier |
|-------|---------:|----:|------:|------------:|------------:|----:|------:|
| Restored baseline LightGBM | 67 | 0.8514 | 0.8453 | 0.7940 | 0.7468 | 0.2060 | 0.1578 |
| Reduced LightGBM | 18 | 0.8434 | 0.8377 | 0.7831 | 0.7383 | 0.2169 | 0.1615 |

## Reduced Input Set (18 model features)

The user-facing flow is split into profile inputs and check-in inputs. BMI and waist-to-height ratio are calculated automatically.

- **Profile inputs (9):** age, sex, race/ethnicity, height, family diabetes history, hypertension history, hypertension medication use, high cholesterol history, gestational diabetes history
- **Check-in inputs (7):** weight, waist circumference, systolic BP optional, diastolic BP optional, smoking status, alcohol frequency, sleep hours
- **Derived model features (2):** BMI, waist-to-height ratio

Detailed diet nutrient averages, supplement nutrient estimates, ten-year weight change, caffeine milligrams, alcohol grams, detailed physical activity, PHQ-9, and sleep-trouble modules are removed from the required flow.

## Lifestyle Suggestion Rules

The prediction model remains separate from daily lifestyle coaching. The
rule-based suggestion engine in `src/lifestyle_suggestions.py` uses recent
check-ins to generate small, non-diagnostic actions across sleep, movement,
diet, alcohol, maintenance, and data-support domains.

Example:

```python
from src.lifestyle_suggestions import generate_lifestyle_suggestions

suggestions = generate_lifestyle_suggestions(
    checkins=[
        {"sleep_hours": 6.0, "movement_break_frequency": "Once"},
        {"sleep_hours": 6.5, "movement_break_frequency": "Not at all"},
        {"sleep_hours": 6.0, "movement_break_frequency": "A few times during the day"},
    ],
    profile={"alcohol_frequency": "monthly"},
)
```

Safety constraints are encoded with each suggestion: the engine does not
diagnose, does not infer behavior from missing check-ins, does not judge from a
single meal, accounts for physical limitations in movement advice, avoids
labeling alcohol use, and does not imply zero risk when reinforcing maintenance.

To inspect concrete sample inputs and outputs, run:

```bash
python examples/lifestyle_suggestion_examples.py
```

The script also writes the rendered examples to
`examples/lifestyle_suggestion_examples_output.txt`.

## License

This project uses publicly available NHANES data. The code is provided for research purposes.
