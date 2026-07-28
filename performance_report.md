# Performance Report

Retrain completed after reducing the model to significant inputs only and splitting user entry into profile fields and daily check-in fields.

For the focused LightGBM-only validation requested after this retrain, including
original-vs-compact comparison, ablations, subgroup calibration, robustness, and
leakage checks, see:

`results/validation/lightgbm_compact_validation_report.md`

## Input Design

Selection rule: kept compact model features from the latest full LightGBM SHAP ranking with `mean_abs_shap >= 0.05`.

Profile inputs, entered once when creating a profile:

1. `age`
2. `race`
3. `height`
4. `hypertension_history`
5. `high_cholesterol`
6. `weight_10yr_ago`

Daily inputs, entered or updated at each check-in:

1. `weight`
2. `waist_circumference`
3. `alcohol_frequency`
4. `diet_alcohol_g_avg`
5. `diet_caffeine_mg_avg`

Derived model features calculated automatically:

1. `bmi`
2. `waist_height_ratio`
3. `weight_change_pct`

Final compact model features:

`age`, `race`, `bmi`, `waist_circumference`, `hypertension_history`, `high_cholesterol`, `alcohol_frequency`, `weight_change_pct`, `waist_height_ratio`, `diet_caffeine_mg_avg`, `diet_alcohol_g_avg`

## Dataset

- Data source: NHANES 2017-2020 and 2021-2023 local raw files.
- Analytic sample: 7,177 adults with valid fasting glucose and insulin for HOMA-IR.
- Train/test split: 5,741 train and 1,436 test, stratified 80:20 with `random_state=42`.
- Target: `insulin_resistance_binary`, positive when HOMA-IR > 2.5.
- Test prevalence: 51.0%.
- Model feature count: 11.

## Model Performance

| Model | AUC | 95% CI | AUPRC | Sensitivity | Specificity | F1 | Brier |
|---|---:|---:|---:|---:|---:|---:|---:|
| FINDRISC | 0.7485 | n/a | 0.7094 | 0.5143 | 0.8179 | 0.6090 | 0.2070 |
| ADA Risk Test | 0.7153 | n/a | 0.6881 | 0.6739 | 0.6060 | 0.6569 | 0.2160 |
| Logistic Regression | 0.8445 | 0.8232-0.8640 | 0.8448 | 0.7517 | 0.7710 | 0.7626 | 0.1616 |
| Random Forest | 0.8401 | 0.8190-0.8598 | 0.8304 | 0.7804 | 0.7525 | 0.7735 | 0.1630 |
| XGBoost | 0.8393 | 0.8184-0.8596 | 0.8324 | 0.9618 | 0.3869 | 0.7544 | 0.2072 |
| LightGBM | 0.8475 | 0.8269-0.8670 | 0.8407 | 0.7858 | 0.7568 | 0.7784 | 0.1595 |
| SVM | 0.8410 | 0.8189-0.8613 | 0.8206 | 0.7954 | 0.7240 | 0.7722 | 0.1616 |
| MLP | 0.8394 | 0.8171-0.8594 | 0.8385 | 0.7613 | 0.7781 | 0.7713 | 0.1637 |

## Best Model

LightGBM was selected as the best model by test AUC:

- AUC: 0.8475
- 95% bootstrap CI: 0.8269-0.8670
- AUPRC: 0.8407
- Sensitivity: 0.7858
- Specificity: 0.7568
- F1: 0.7784
- Brier score: 0.1595

Compared with the previous 67-feature retrain, the compact model reduced the model feature count from 67 to 11 while decreasing best-model AUC from 0.8514 to 0.8475.

## Top SHAP Features After Compact Retrain

| Rank | Feature | Mean Abs SHAP |
|---:|---|---:|
| 1 | `waist_circumference` | 0.5842 |
| 2 | `waist_height_ratio` | 0.3918 |
| 3 | `bmi` | 0.3000 |
| 4 | `race` | 0.1364 |
| 5 | `hypertension_history` | 0.1346 |
| 6 | `age` | 0.1199 |
| 7 | `diet_alcohol_g_avg` | 0.1162 |
| 8 | `weight_change_pct` | 0.0917 |
| 9 | `high_cholesterol` | 0.0842 |
| 10 | `diet_caffeine_mg_avg` | 0.0827 |
| 11 | `alcohol_frequency` | 0.0543 |

## Subgroup AUC

| Group | Subgroup | N | Prevalence | AUC | 95% CI |
|---|---|---:|---:|---:|---:|
| Age | 18-39 | 428 | 0.446 | 0.8673 | 0.8329-0.9020 |
| Age | 40-59 | 441 | 0.522 | 0.8673 | 0.8330-0.8972 |
| Age | 60+ | 567 | 0.550 | 0.8063 | 0.7714-0.8395 |
| Sex | Male | 670 | 0.524 | 0.8484 | 0.8185-0.8764 |
| Sex | Female | 766 | 0.499 | 0.8485 | 0.8213-0.8732 |
| Race | NH White | 655 | 0.464 | 0.8620 | 0.8345-0.8874 |
| Race | NH Black | 273 | 0.531 | 0.8700 | 0.8268-0.9114 |
| Race | Hispanic | 301 | 0.608 | 0.8189 | 0.7716-0.8703 |
| Race | Other | 207 | 0.488 | 0.7917 | 0.7355-0.8484 |
| BMI | Normal (<25) | 392 | 0.138 | 0.6929 | 0.5999-0.7589 |
| BMI | Overweight (25-30) | 443 | 0.465 | 0.6930 | 0.6424-0.7413 |
| BMI | Obese (>=30) | 601 | 0.787 | 0.7501 | 0.7022-0.7969 |

## Notes

- The compact significant-input model preserves nearly all discrimination from the larger model.
- LightGBM remains the best overall model, but Logistic Regression is close and may be attractive if calibration, simplicity, or deployment transparency become the priority.
- The new helper `prepare_checkin_features(profile_input, daily_input, ...)` converts the two user input groups into the 11 model features and was smoke-tested against the retrained LightGBM model.
