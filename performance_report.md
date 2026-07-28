# Performance Report

Retrain completed after enabling optional user blood pressure inputs.

## Dataset And Feature Setup

- Data source: NHANES 2017-2020 and 2021-2023 local raw files.
- Analytic sample: 7,177 adults with valid fasting glucose and insulin for HOMA-IR.
- Train/test split: 5,741 train and 1,436 test, stratified 80:20 with `random_state=42`.
- Target: `insulin_resistance_binary`, positive when HOMA-IR > 2.5.
- Test prevalence: 51.0%.
- Model feature count used in this retrain: 67.
- Optional user-entered BP fields available in current data: `systolic_bp`, `diastolic_bp`.
- `pulse` remains configured as optional, but is absent from the current processed dataset/results.

The retrained preprocessing artifact is saved at `results/models/preprocessor.joblib`.
Optional BP inputs are accepted when entered and imputed when omitted.

## Model Performance

| Model | AUC | 95% CI | AUPRC | Sensitivity | Specificity | F1 | Brier |
|---|---:|---:|---:|---:|---:|---:|---:|
| FINDRISC | 0.7490 | n/a | 0.7090 | 0.5171 | 0.8179 | 0.6113 | 0.2069 |
| ADA Risk Test | 0.7154 | n/a | 0.6880 | 0.6739 | 0.6031 | 0.6560 | 0.2160 |
| Logistic Regression | 0.8460 | 0.8260-0.8653 | 0.8460 | 0.7681 | 0.7454 | 0.7634 | 0.1608 |
| Random Forest | 0.8458 | 0.8249-0.8652 | 0.8415 | 0.7790 | 0.7340 | 0.7659 | 0.1624 |
| XGBoost | 0.8513 | 0.8307-0.8708 | 0.8489 | 0.7913 | 0.7454 | 0.7775 | 0.1566 |
| LightGBM | 0.8514 | 0.8303-0.8696 | 0.8453 | 0.7940 | 0.7468 | 0.7796 | 0.1578 |
| SVM | 0.8446 | 0.8219-0.8642 | 0.8337 | 0.7831 | 0.7624 | 0.7788 | 0.1614 |
| MLP | 0.8420 | 0.8213-0.8620 | 0.8408 | 0.6944 | 0.7994 | 0.7361 | 0.1641 |

## Best Model

LightGBM was selected as the best model by test AUC:

- AUC: 0.8514
- 95% bootstrap CI: 0.8303-0.8696
- AUPRC: 0.8453
- Sensitivity: 0.7940
- Specificity: 0.7468
- F1: 0.7796
- Brier score: 0.1578

XGBoost was effectively tied on discrimination with AUC 0.8513 and the highest AUPRC at 0.8489.

## Top SHAP Features

Top LightGBM features by mean absolute SHAP value:

| Rank | Feature | Mean Abs SHAP |
|---:|---|---:|
| 1 | `bmi` | 0.5317 |
| 2 | `waist_height_ratio` | 0.3609 |
| 3 | `waist_circumference` | 0.3109 |
| 4 | `hypertension_history` | 0.1014 |
| 5 | `race` | 0.0978 |
| 6 | `diet_alcohol_g_avg` | 0.0959 |
| 7 | `age` | 0.0823 |
| 8 | `high_cholesterol` | 0.0744 |
| 9 | `diet_caffeine_mg_avg` | 0.0663 |
| 10 | `weight_change_pct` | 0.0544 |

## Subgroup AUC

| Group | Subgroup | N | Prevalence | AUC | 95% CI |
|---|---|---:|---:|---:|---:|
| Age | 18-39 | 428 | 0.446 | 0.8713 | 0.8372-0.9066 |
| Age | 40-59 | 441 | 0.522 | 0.8675 | 0.8326-0.8960 |
| Age | 60+ | 567 | 0.550 | 0.8129 | 0.7805-0.8461 |
| Sex | Male | 670 | 0.524 | 0.8549 | 0.8258-0.8848 |
| Sex | Female | 766 | 0.499 | 0.8490 | 0.8210-0.8728 |
| Race | NH White | 655 | 0.464 | 0.8684 | 0.8426-0.8946 |
| Race | NH Black | 273 | 0.531 | 0.8757 | 0.8296-0.9149 |
| Race | Hispanic | 301 | 0.608 | 0.8167 | 0.7667-0.8659 |
| Race | Other | 207 | 0.488 | 0.8028 | 0.7461-0.8612 |
| BMI | Normal (<25) | 392 | 0.138 | 0.7359 | 0.6582-0.8001 |
| BMI | Overweight (25-30) | 438 | 0.463 | 0.6992 | 0.6523-0.7454 |
| BMI | Obese (>=30) | 606 | 0.785 | 0.7562 | 0.7002-0.8009 |

## Notes

- The strongest ML models substantially outperformed FINDRISC and the ADA Risk Test on AUC.
- Performance was strongest in younger and middle-aged groups and weaker within BMI strata, especially overweight participants.
- Direct BP measurements are not mandatory for user prediction. When omitted, preprocessing fills optional BP inputs using the fitted training preprocessor before model prediction.
