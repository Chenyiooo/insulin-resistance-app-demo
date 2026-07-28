# Beyond the Blood Draw

**Explainable Machine Learning for Non-Invasive Insulin Resistance Screening**

This repository contains the full reproducible pipeline for the paper:

> Black Sun\*, Chenyi Zhang\*, Xi Lu. *Beyond the Blood Draw: Explainable Machine Learning for Non-Invasive Type 2 Diabetes Risk Screening.* AMIA 2026 Annual Symposium.

## Overview

We develop and validate machine learning models for insulin resistance screening using a compact **11-feature significant-input model** from the National Health and Nutrition Examination Survey (NHANES) 2017--2023. User inputs are split into profile fields entered once and daily check-in fields. The learning target is lab-defined insulin resistance from HOMA-IR.

The HOMA-IR label is calculated from fasting glucose and insulin:

```text
HOMA-IR = LBDGLUSI (mmol/L) * LBXIN (mIU/L) / 22.5
insulin_resistance_binary = 1 if HOMA-IR > 2.5
```

`LBDGLUSI`, `LBXIN`, and `homa_ir` are used only to define the target and are not included as model inputs.

**Key results:**
- LightGBM achieves AUC = 0.820 (95% CI: 0.806--0.835), outperforming FINDRISC (0.745) and the ADA Risk Test (0.783)
- SHAP analysis identifies age, race/ethnicity, waist-to-height ratio, antihypertensive medication use, and family diabetes history as top predictors
- Consistent performance across age, sex, race/ethnicity, and BMI subgroups (AUC: 0.735--0.832)

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

## Models

| Model | AUC | 95% CI |
|-------|-----|--------|
| FINDRISC | 0.745 | -- |
| ADA Risk Test | 0.783 | -- |
| Logistic Regression | 0.812 | 0.797--0.826 |
| Random Forest | 0.814 | 0.799--0.829 |
| SVM (RBF) | 0.809 | 0.794--0.825 |
| MLP | 0.814 | 0.799--0.829 |
| XGBoost | 0.816 | 0.800--0.831 |
| **LightGBM** | **0.820** | **0.806--0.835** |

## Significant Input Set (11 model features)

The compact model keeps features with mean absolute SHAP importance >= 0.05 from the latest LightGBM retrain. The user-facing flow is split into profile inputs and daily check-in inputs; derived model fields are calculated automatically.

- **Profile inputs (6):** age, race/ethnicity, height, hypertension history, high cholesterol history, weight 10 years ago
- **Daily inputs (5):** weight, waist circumference, alcohol frequency, average alcohol intake, average caffeine intake
- **Derived model features (3):** BMI, waist-to-height ratio, 10-year weight change %

## License

This project uses publicly available NHANES data. The code is provided for research purposes.
