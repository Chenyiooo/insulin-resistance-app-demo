# LightGBM Compact Model Validation

This validation retrains LightGBM only. All comparisons use the same train/test split.

## Main Comparison

| model                          |   n_features |    auc |   auprc |   sensitivity |   specificity |     f1 |   false_negative_rate |   brier |   ece_10bin |   calibration_slope |   calibration_intercept |
|:-------------------------------|-------------:|-------:|--------:|--------------:|--------------:|-------:|----------------------:|--------:|------------:|--------------------:|------------------------:|
| original_67                    |           67 | 0.8511 |  0.8489 |        0.7899 |        0.7440 | 0.7761 |                0.2101 |  0.1579 |      0.0423 |              1.1842 |                 -0.0024 |
| compact_11                     |           11 | 0.8475 |  0.8407 |        0.7858 |        0.7568 | 0.7784 |                0.2142 |  0.1595 |      0.0324 |              1.1266 |                  0.0065 |
| compact_no_race                |           10 | 0.8434 |  0.8387 |        0.7790 |        0.7454 | 0.7701 |                0.2210 |  0.1617 |      0.0274 |              1.1176 |                  0.0055 |
| compact_no_weight_change       |           10 | 0.8475 |  0.8395 |        0.7885 |        0.7511 | 0.7779 |                0.2115 |  0.1595 |      0.0305 |              1.1272 |                  0.0036 |
| compact_no_alcohol             |            9 | 0.8456 |  0.8410 |        0.7831 |        0.7468 | 0.7731 |                0.2169 |  0.1605 |      0.0387 |              1.1222 |                  0.0202 |
| compact_no_caffeine            |           10 | 0.8444 |  0.8380 |        0.7790 |        0.7553 | 0.7737 |                0.2210 |  0.1609 |      0.0292 |              1.1040 |                  0.0116 |
| compact_alcohol_frequency_only |           10 | 0.8470 |  0.8414 |        0.7858 |        0.7468 | 0.7747 |                0.2142 |  0.1597 |      0.0350 |              1.1186 |                  0.0115 |
| compact_diet_alcohol_only      |           10 | 0.8465 |  0.8390 |        0.7844 |        0.7496 | 0.7749 |                0.2156 |  0.1599 |      0.0299 |              1.1206 |                  0.0104 |
| train_cv_selected_11           |           11 | 0.8495 |  0.8462 |        0.7872 |        0.7568 | 0.7792 |                0.2128 |  0.1585 |      0.0362 |              1.1471 |                  0.0014 |

## Key Findings

- Original 67-feature LightGBM AUC: 0.8511.
- Compact 11-feature LightGBM AUC: 0.8475.
- Compact model AUPRC: 0.8407; F1: 0.7784.
- Removing race changed AUC from 0.8475 to 0.8434 and false-negative rate from 0.2142 to 0.2210.

## Train-Only Feature Selection Leakage Check

Feature selection was re-run using only the training split with 5-fold CV LightGBM gain importance. The held-out test split was not used for this selection check.

Top 11 train-CV selected features:

`waist_height_ratio`, `waist_circumference`, `bmi`, `age`, `race`, `diet_alcohol_g_avg`, `weight_change_pct`, `diet_caffeine_mg_avg`, `diastolic_bp`, `weight`, `hypertension_history`

The proposed compact feature set should be treated as a product candidate, not as a final locked clinical feature set, unless it matches the train-only selection criterion or is frozen before external validation.

## Race And Sex Subgroup Metrics

| model           | group   | subgroup   |   n |   prevalence |    auc |   auprc |   sensitivity |   specificity |     f1 |   false_negative_rate |   brier |   ece_10bin |   calibration_slope |   calibration_intercept |
|:----------------|:--------|:-----------|----:|-------------:|-------:|--------:|--------------:|--------------:|-------:|----------------------:|--------:|------------:|--------------------:|------------------------:|
| compact_11      | sex     | Male       | 670 |       0.5239 | 0.8484 |  0.8506 |        0.7721 |        0.7743 | 0.7810 |                0.2279 |  0.1593 |      0.0430 |              1.1574 |                  0.1425 |
| compact_11      | sex     | Female     | 766 |       0.4987 | 0.8485 |  0.8348 |        0.7984 |        0.7422 | 0.7761 |                0.2016 |  0.1597 |      0.0452 |              1.1098 |                 -0.1125 |
| compact_11      | race    | Hispanic   | 301 |       0.6080 | 0.8189 |  0.8549 |        0.8251 |        0.6441 | 0.8032 |                0.1749 |  0.1648 |      0.0554 |              1.0296 |                  0.0851 |
| compact_11      | race    | NH White   | 655 |       0.4641 | 0.8620 |  0.8396 |        0.7829 |        0.7835 | 0.7702 |                0.2171 |  0.1525 |      0.0422 |              1.2437 |                 -0.1617 |
| compact_11      | race    | NH Black   | 273 |       0.5311 | 0.8700 |  0.8630 |        0.8069 |        0.7500 | 0.7959 |                0.1931 |  0.1490 |      0.0536 |              1.1885 |                  0.1088 |
| compact_11      | race    | Other      | 207 |       0.4879 | 0.7917 |  0.7995 |        0.6931 |        0.8019 | 0.7292 |                0.3069 |  0.1878 |      0.0943 |              0.9146 |                  0.2282 |
| compact_no_race | sex     | Male       | 670 |       0.5239 | 0.8462 |  0.8534 |        0.7550 |        0.7774 | 0.7715 |                0.2450 |  0.1604 |      0.0331 |              1.1559 |                  0.1472 |
| compact_no_race | sex     | Female     | 766 |       0.4987 | 0.8426 |  0.8285 |        0.8010 |        0.7188 | 0.7688 |                0.1990 |  0.1629 |      0.0439 |              1.0959 |                 -0.1162 |
| compact_no_race | race    | Hispanic   | 301 |       0.6080 | 0.8207 |  0.8617 |        0.7923 |        0.6780 | 0.7923 |                0.2077 |  0.1671 |      0.0606 |              1.1799 |                  0.2487 |
| compact_no_race | race    | NH White   | 655 |       0.4641 | 0.8616 |  0.8394 |        0.8191 |        0.7379 | 0.7721 |                0.1809 |  0.1547 |      0.0542 |              1.2399 |                 -0.3048 |
| compact_no_race | race    | NH Black   | 273 |       0.5311 | 0.8661 |  0.8580 |        0.8414 |        0.7188 | 0.8053 |                0.1586 |  0.1500 |      0.0695 |              1.1447 |                 -0.0363 |
| compact_no_race | race    | Other      | 207 |       0.4879 | 0.7906 |  0.7950 |        0.5446 |        0.8774 | 0.6509 |                0.4554 |  0.1917 |      0.0851 |              0.9300 |                  0.4413 |

## Weight History Robustness

| scenario                         |    auc |   auprc |   sensitivity |   specificity |     f1 |   false_negative_rate |   brier |   ece_10bin |   calibration_slope |   calibration_intercept |
|:---------------------------------|-------:|--------:|--------------:|--------------:|-------:|----------------------:|--------:|------------:|--------------------:|------------------------:|
| missing_weight_10yr              | 0.8477 |  0.8407 |        0.7626 |        0.7738 | 0.7705 |                0.2374 |  0.1593 |      0.0300 |              1.1153 |                  0.1021 |
| weight_10yr_underestimated_10pct | 0.8485 |  0.8426 |        0.7913 |        0.7553 | 0.7811 |                0.2087 |  0.1591 |      0.0356 |              1.1349 |                 -0.0184 |
| weight_10yr_overestimated_10pct  | 0.8459 |  0.8372 |        0.7817 |        0.7624 | 0.7780 |                0.2183 |  0.1603 |      0.0322 |              1.1292 |                  0.0456 |
| weight_10yr_underestimated_20pct | 0.8482 |  0.8427 |        0.7899 |        0.7553 | 0.7803 |                0.2101 |  0.1593 |      0.0388 |              1.1355 |                 -0.0317 |
| weight_10yr_overestimated_20pct  | 0.8436 |  0.8342 |        0.7749 |        0.7767 | 0.7791 |                0.2251 |  0.1616 |      0.0409 |              1.1268 |                  0.0878 |

## Diet Record Duration

NHANES provides up to two 24-hour dietary recall days, so this dataset can directly validate one-day versus two-day averages only. Three-day and seven-day reliability require prospective app data or another dataset with longer food logs.

| scenario                |    auc |   auprc |   sensitivity |   specificity |     f1 |   false_negative_rate |   brier |   ece_10bin |   calibration_slope |   calibration_intercept |
|:------------------------|-------:|--------:|--------------:|--------------:|-------:|----------------------:|--------:|------------:|--------------------:|------------------------:|
| two_day_average_current | 0.8475 |  0.8407 |        0.7858 |        0.7568 | 0.7784 |                0.2142 |  0.1595 |      0.0324 |              1.1266 |                  0.0065 |
| day1_only               | 0.8467 |  0.8406 |        0.7831 |        0.7440 | 0.7720 |                0.2169 |  0.1600 |      0.0322 |              1.1264 |                 -0.0115 |
| day2_only               | 0.8451 |  0.8355 |        0.7940 |        0.7397 | 0.7770 |                0.2060 |  0.1606 |      0.0370 |              1.1199 |                 -0.0399 |
| no_diet_average_inputs  | 0.8419 |  0.8353 |        0.8063 |        0.7112 | 0.7741 |                0.1937 |  0.1633 |      0.0430 |              1.1206 |                 -0.1283 |

## Alcohol Redundancy

| model                          |   n_features |    auc |   auprc |   sensitivity |   specificity |     f1 |   false_negative_rate |   brier |   ece_10bin |   calibration_slope |   calibration_intercept |
|:-------------------------------|-------------:|-------:|--------:|--------------:|--------------:|-------:|----------------------:|--------:|------------:|--------------------:|------------------------:|
| compact_11                     |           11 | 0.8475 |  0.8407 |        0.7858 |        0.7568 | 0.7784 |                0.2142 |  0.1595 |      0.0324 |              1.1266 |                  0.0065 |
| compact_no_alcohol             |            9 | 0.8456 |  0.8410 |        0.7831 |        0.7468 | 0.7731 |                0.2169 |  0.1605 |      0.0387 |              1.1222 |                  0.0202 |
| compact_alcohol_frequency_only |           10 | 0.8470 |  0.8414 |        0.7858 |        0.7468 | 0.7747 |                0.2142 |  0.1597 |      0.0350 |              1.1186 |                  0.0115 |
| compact_diet_alcohol_only      |           10 | 0.8465 |  0.8390 |        0.7844 |        0.7496 | 0.7749 |                0.2156 |  0.1599 |      0.0299 |              1.1206 |                  0.0104 |

## Product Input Frequency Recommendation

- Profile information: entered once and updated when demographics or clinical history changes.
- Weight: weekly is enough for risk tracking; daily entry may create unnecessary burden.
- Waist circumference: monthly is a better fit because measurement error is high and changes slowly.
- Alcohol and caffeine: optional behavioral records used to calculate longer-term averages. The app should avoid requiring daily diet logging for core screening.

## Calibration Definitions

- Brier score: lower is better.
- ECE 10-bin: expected calibration error across 10 probability bins; lower is better.
- Calibration slope near 1 and intercept near 0 indicate better calibration.
