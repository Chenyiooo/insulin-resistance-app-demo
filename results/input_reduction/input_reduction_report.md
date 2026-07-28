# Input Reduction From Original 67 Features

LightGBM-only validation from the restored 67-feature baseline. Variants use the same train/test split and metrics.

## Performance Summary

| model                                  |   n_features |    auc |   auprc |   sensitivity |   specificity |     f1 |    fnr |   brier |   ece_10bin |   calibration_slope |   calibration_intercept |   auc_ci_low |   auc_ci_high |   auprc_ci_low |   auprc_ci_high |   fnr_ci_low |   fnr_ci_high |   brier_ci_low |   brier_ci_high |   ece_10bin_ci_low |   ece_10bin_ci_high |
|:---------------------------------------|-------------:|-------:|--------:|--------------:|--------------:|-------:|-------:|--------:|------------:|--------------------:|------------------------:|-------------:|--------------:|---------------:|----------------:|-------------:|--------------:|---------------:|----------------:|-------------------:|--------------------:|
| baseline_67                            |           67 | 0.8514 |  0.8453 |        0.7940 |        0.7468 | 0.7796 | 0.2060 |  0.1578 |      0.0314 |              1.1954 |                 -0.0008 |       0.8322 |        0.8718 |         0.8174 |          0.8715 |       0.1772 |        0.2365 |         0.1479 |          0.1673 |             0.0297 |              0.0596 |
| no_supplements                         |           47 | 0.8475 |  0.8430 |        0.7940 |        0.7440 | 0.7786 | 0.2060 |  0.1597 |      0.0352 |              1.1679 |                 -0.0008 |       0.8276 |        0.8673 |         0.8156 |          0.8693 |       0.1751 |        0.2359 |         0.1499 |          0.1693 |             0.0302 |              0.0602 |
| no_detailed_diet                       |           49 | 0.8488 |  0.8422 |        0.7940 |        0.7425 | 0.7781 | 0.2060 |  0.1592 |      0.0339 |              1.1790 |                  0.0159 |       0.8286 |        0.8694 |         0.8146 |          0.8667 |       0.1741 |        0.2329 |         0.1491 |          0.1689 |             0.0329 |              0.0618 |
| clinical_screen_no_diet_supp           |           29 | 0.8437 |  0.8387 |        0.7817 |        0.7383 | 0.7691 | 0.2183 |  0.1613 |      0.0390 |              1.1368 |                  0.0227 |       0.8236 |        0.8648 |         0.8108 |          0.8637 |       0.1851 |        0.2461 |         0.1508 |          0.1709 |             0.0291 |              0.0620 |
| clinical_screen_no_bp                  |           27 | 0.8447 |  0.8383 |        0.7858 |        0.7397 | 0.7721 | 0.2142 |  0.1608 |      0.0372 |              1.1357 |                  0.0264 |       0.8245 |        0.8656 |         0.8106 |          0.8634 |       0.1838 |        0.2388 |         0.1504 |          0.1703 |             0.0290 |              0.0612 |
| clinical_screen_no_race                |           28 | 0.8424 |  0.8391 |        0.7831 |        0.7397 | 0.7705 | 0.2169 |  0.1623 |      0.0363 |              1.1519 |                  0.0204 |       0.8231 |        0.8633 |         0.8104 |          0.8640 |       0.1851 |        0.2459 |         0.1522 |          0.1717 |             0.0286 |              0.0621 |
| clinical_screen_no_weight_history      |           28 | 0.8449 |  0.8394 |        0.7899 |        0.7383 | 0.7741 | 0.2101 |  0.1609 |      0.0356 |              1.1473 |                  0.0143 |       0.8252 |        0.8654 |         0.8106 |          0.8641 |       0.1799 |        0.2386 |         0.1507 |          0.1704 |             0.0279 |              0.0620 |
| clinical_screen_no_alcohol             |           27 | 0.8416 |  0.8359 |        0.7817 |        0.7354 | 0.7681 | 0.2183 |  0.1626 |      0.0351 |              1.1249 |                  0.0243 |       0.8206 |        0.8625 |         0.8065 |          0.8624 |       0.1860 |        0.2502 |         0.1524 |          0.1724 |             0.0266 |              0.0579 |
| clinical_screen_no_activity_sleep_mood |           21 | 0.8442 |  0.8386 |        0.7844 |        0.7411 | 0.7718 | 0.2156 |  0.1613 |      0.0300 |              1.1325 |                  0.0203 |       0.8240 |        0.8649 |         0.8098 |          0.8641 |       0.1831 |        0.2451 |         0.1510 |          0.1710 |             0.0264 |              0.0563 |
| low_burden_screen_optional_bp          |           18 | 0.8457 |  0.8410 |        0.7940 |        0.7383 | 0.7765 | 0.2060 |  0.1606 |      0.0298 |              1.1593 |                  0.0119 |       0.8263 |        0.8672 |         0.8132 |          0.8654 |       0.1748 |        0.2338 |         0.1502 |          0.1700 |             0.0246 |              0.0560 |
| low_burden_screen_no_bp                |           16 | 0.8452 |  0.8397 |        0.7885 |        0.7425 | 0.7748 | 0.2115 |  0.1607 |      0.0317 |              1.1440 |                  0.0250 |       0.8264 |        0.8659 |         0.8104 |          0.8647 |       0.1816 |        0.2396 |         0.1504 |          0.1700 |             0.0295 |              0.0583 |
| low_burden_no_race                     |           17 | 0.8411 |  0.8387 |        0.7885 |        0.7240 | 0.7681 | 0.2115 |  0.1630 |      0.0376 |              1.1417 |                  0.0130 |       0.8215 |        0.8627 |         0.8089 |          0.8649 |       0.1789 |        0.2424 |         0.1525 |          0.1726 |             0.0311 |              0.0628 |
| low_burden_no_alcohol                  |           17 | 0.8434 |  0.8402 |        0.7899 |        0.7368 | 0.7735 | 0.2101 |  0.1617 |      0.0278 |              1.1497 |                  0.0104 |       0.8240 |        0.8646 |         0.8114 |          0.8645 |       0.1764 |        0.2401 |         0.1510 |          0.1709 |             0.0240 |              0.0541 |

## Recommendation

Use a two-tier product model:

1. Default low-burden screening model with optional BP: 18 model features.
2. Optional clinical/lifestyle extension: 29 model features without detailed diet nutrients or supplement nutrient estimates.

The 18-feature model AUC is 0.8457 versus baseline 67-feature AUC 0.8514.
The 29-feature clinical screen AUC is 0.8437.

The largest burden reduction should come from deleting supplement nutrient estimates and detailed diet nutrient averages from the required flow. Their real-world measurement burden is high, and the model loss is modest compared with the user-experience gain.

## Input Group Decisions

| group                   | recommendation                | reason                                                                                                        |
|:------------------------|:------------------------------|:--------------------------------------------------------------------------------------------------------------|
| supplements             | delete                        | High burden, high missingness, low real-world reliability for users to estimate nutrient mg from supplements. |
| detailed diet nutrients | delete by default             | Requires diet logging and nutrient estimation; NHANES only gives 1-2 recalls.                                 |
| blood pressure          | optional                      | Useful and clinically coherent but requires equipment; impute if omitted.                                     |
| race                    | keep with fairness monitoring | Predictive and affects subgroup error tradeoffs; ethically sensitive.                                         |
| ten-year weight change  | optional / avoid required     | Clinically plausible but recall reliability is poor and missingness is high.                                  |
| activity/sleep/mood     | optional module               | Some clinical value but more repeated questionnaire burden.                                                   |
| alcohol                 | keep simple frequency only    | Frequency captures most alcohol signal; detailed grams are burdensome.                                        |
| caffeine                | optional trend feature        | Milligram estimates are unreliable for users and only modestly predictive.                                    |

## Robustness And Fairness Snapshot

| model                         | group   | subgroup   |   n |   prevalence |    auc |   auprc |   sensitivity |   specificity |     f1 |    fnr |   brier |   ece_10bin |   calibration_slope |   calibration_intercept |
|:------------------------------|:--------|:-----------|----:|-------------:|-------:|--------:|--------------:|--------------:|-------:|-------:|--------:|------------:|--------------------:|------------------------:|
| baseline_67                   | sex     | Male       | 670 |       0.5239 | 0.8549 |  0.8613 |        0.7778 |        0.7649 | 0.7811 | 0.2222 |  0.1557 |      0.0416 |              1.1915 |                  0.0881 |
| baseline_67                   | sex     | Female     | 766 |       0.4987 | 0.8490 |  0.8334 |        0.8089 |        0.7318 | 0.7783 | 0.1911 |  0.1597 |      0.0380 |              1.2038 |                 -0.0771 |
| baseline_67                   | race    | Hispanic   | 301 |       0.6080 | 0.8167 |  0.8584 |        0.8197 |        0.6525 | 0.8021 | 0.1803 |  0.1674 |      0.0800 |              1.0881 |                  0.1166 |
| baseline_67                   | race    | NH White   | 655 |       0.4641 | 0.8684 |  0.8487 |        0.8092 |        0.7607 | 0.7760 | 0.1908 |  0.1499 |      0.0493 |              1.3282 |                 -0.1963 |
| baseline_67                   | race    | NH Black   | 273 |       0.5311 | 0.8757 |  0.8698 |        0.8207 |        0.7344 | 0.7987 | 0.1793 |  0.1465 |      0.0862 |              1.2587 |                  0.0414 |
| baseline_67                   | race    | Other      | 207 |       0.4879 | 0.8028 |  0.7951 |        0.6634 |        0.8208 | 0.7166 | 0.3366 |  0.1838 |      0.0813 |              0.9895 |                  0.2836 |
| baseline_67                   | age     | 18-39      | 428 |       0.4463 | 0.8713 |  0.8523 |        0.7801 |        0.8354 | 0.7863 | 0.2199 |  0.1423 |      0.0430 |              1.1581 |                 -0.0683 |
| baseline_67                   | age     | 40-59      | 441 |       0.5215 | 0.8675 |  0.8856 |        0.8217 |        0.7156 | 0.7891 | 0.1783 |  0.1510 |      0.0438 |              1.3261 |                 -0.0196 |
| baseline_67                   | age     | 60+        | 567 |       0.5503 | 0.8129 |  0.8046 |        0.7821 |        0.6902 | 0.7685 | 0.2179 |  0.1749 |      0.0475 |              1.1223 |                  0.0506 |
| low_burden_screen_optional_bp | sex     | Male       | 670 |       0.5239 | 0.8475 |  0.8536 |        0.7806 |        0.7586 | 0.7806 | 0.2194 |  0.1593 |      0.0402 |              1.1531 |                  0.0815 |
| low_burden_screen_optional_bp | sex     | Female     | 766 |       0.4987 | 0.8445 |  0.8317 |        0.8063 |        0.7214 | 0.7729 | 0.1937 |  0.1618 |      0.0552 |              1.1673 |                 -0.0485 |
| low_burden_screen_optional_bp | race    | Hispanic   | 301 |       0.6080 | 0.8082 |  0.8523 |        0.8033 |        0.6441 | 0.7903 | 0.1967 |  0.1707 |      0.0543 |              1.0291 |                  0.1456 |
| low_burden_screen_optional_bp | race    | NH White   | 655 |       0.4641 | 0.8623 |  0.8427 |        0.7928 |        0.7407 | 0.7579 | 0.2072 |  0.1531 |      0.0593 |              1.3021 |                 -0.1657 |
| low_burden_screen_optional_bp | race    | NH Black   | 273 |       0.5311 | 0.8699 |  0.8657 |        0.8414 |        0.7500 | 0.8161 | 0.1586 |  0.1489 |      0.0585 |              1.2146 |                  0.0486 |
| low_burden_screen_optional_bp | race    | Other      | 207 |       0.4879 | 0.8011 |  0.7968 |        0.7129 |        0.8208 | 0.7500 | 0.2871 |  0.1853 |      0.0949 |              0.9439 |                  0.2533 |
| low_burden_screen_optional_bp | age     | 18-39      | 428 |       0.4463 | 0.8669 |  0.8447 |        0.7801 |        0.8228 | 0.7801 | 0.2199 |  0.1451 |      0.0331 |              1.1040 |                 -0.0364 |
| low_burden_screen_optional_bp | age     | 40-59      | 441 |       0.5215 | 0.8612 |  0.8788 |        0.8130 |        0.7062 | 0.7808 | 0.1870 |  0.1540 |      0.0524 |              1.2765 |                 -0.0209 |
| low_burden_screen_optional_bp | age     | 60+        | 567 |       0.5503 | 0.8082 |  0.8053 |        0.7885 |        0.6863 | 0.7712 | 0.2115 |  0.1775 |      0.0529 |              1.1157 |                  0.0550 |
| low_burden_no_race            | sex     | Male       | 670 |       0.5239 | 0.8462 |  0.8552 |        0.7863 |        0.7555 | 0.7830 | 0.2137 |  0.1599 |      0.0476 |              1.1353 |                  0.0710 |
| low_burden_no_race            | sex     | Female     | 766 |       0.4987 | 0.8370 |  0.8252 |        0.7906 |        0.6979 | 0.7550 | 0.2094 |  0.1658 |      0.0470 |              1.1490 |                 -0.0362 |
| low_burden_no_race            | race    | Hispanic   | 301 |       0.6080 | 0.8113 |  0.8574 |        0.7923 |        0.6525 | 0.7859 | 0.2077 |  0.1722 |      0.0656 |              1.1480 |                  0.2859 |
| low_burden_no_race            | race    | NH White   | 655 |       0.4641 | 0.8604 |  0.8413 |        0.8191 |        0.7009 | 0.7568 | 0.1809 |  0.1557 |      0.0676 |              1.2996 |                 -0.3043 |
| low_burden_no_race            | race    | NH Black   | 273 |       0.5311 | 0.8650 |  0.8602 |        0.8483 |        0.7266 | 0.8119 | 0.1517 |  0.1504 |      0.0656 |              1.1643 |                 -0.0260 |
| low_burden_no_race            | race    | Other      | 207 |       0.4879 | 0.7983 |  0.7929 |        0.6040 |        0.8774 | 0.6971 | 0.3960 |  0.1897 |      0.1008 |              0.9408 |                  0.4280 |
| low_burden_no_race            | age     | 18-39      | 428 |       0.4463 | 0.8636 |  0.8426 |        0.7906 |        0.8017 | 0.7763 | 0.2094 |  0.1474 |      0.0346 |              1.0845 |                 -0.0466 |
| low_burden_no_race            | age     | 40-59      | 441 |       0.5215 | 0.8551 |  0.8767 |        0.7913 |        0.7014 | 0.7663 | 0.2087 |  0.1573 |      0.0715 |              1.2575 |                  0.0058 |
| low_burden_no_race            | age     | 60+        | 567 |       0.5503 | 0.8038 |  0.8053 |        0.7853 |        0.6706 | 0.7644 | 0.2147 |  0.1793 |      0.0487 |              1.0994 |                  0.0480 |

## Notes

- Bootstrap intervals are included for AUC, AUPRC, FNR, Brier, and ECE in the CSV output.
- Feature reduction here is based on held-out performance deltas, calibration, burden/reliability, and subgroup behavior, not SHAP alone.
- The final feature set should still be frozen before external validation to avoid post-test-set tuning.
