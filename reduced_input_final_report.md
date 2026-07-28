# Reduced Input Final Report

We restored the original 67-feature baseline, then reduced inputs using the requested criteria:

- Predictive value: AUC, AUPRC, FNR, Brier score, ECE, calibration slope/intercept, and bootstrap intervals.
- Measurement reliability: whether users can realistically provide accurate values.
- User burden: time, equipment, and repeated-record effort.
- Clinical and temporal validity: whether the variable is medically coherent and stable enough for screening.
- Robustness and fairness: subgroup error and calibration behavior by sex, race, and age.

## Active Recommendation

Use the **18-feature low-burden LightGBM screen with optional BP**.

This removes detailed diet nutrient averages, supplement/antacid nutrient estimates, caffeine milligram estimates, alcohol gram estimates, ten-year weight change, detailed activity modules, PHQ-9, and sleep-trouble modules from the required flow.

## Active User Inputs

Profile inputs, entered once or updated occasionally:

1. age
2. sex
3. race
4. height
5. family_diabetes
6. hypertension_history
7. hypertension_med
8. high_cholesterol
9. gestational_diabetes

Check-in inputs, updated periodically:

1. weight
2. waist_circumference
3. systolic_bp, optional
4. diastolic_bp, optional
5. smoking_status
6. alcohol_frequency
7. sleep_hours

Derived automatically:

1. bmi
2. waist_height_ratio

## Active Retrained Bundle

The active reduced model was retrained after rebuilding the dataset with the 18-feature configuration.

- Bundle: `results/models/reduced_lightgbm_bundle.joblib`
- Features: 18
- AUC: 0.8434
- AUPRC: 0.8377
- Sensitivity: 0.7831
- Specificity: 0.7383
- FNR: 0.2169
- F1: 0.7700
- Brier: 0.1615
- ECE 10-bin: 0.0300

For comparison, the restored 67-feature LightGBM baseline in the input-reduction experiment had:

- AUC: 0.8514
- AUPRC: 0.8453
- Sensitivity: 0.7940
- Specificity: 0.7468
- FNR: 0.2060
- Brier: 0.1578
- ECE 10-bin: 0.0314

## Evidence Summary

The strongest reduction signal is that the high-burden features can be removed with modest loss:

- Removing supplements only: AUC 0.8475.
- Removing detailed diet only: AUC 0.8488.
- Low-burden screen with optional BP, evaluated from the 67-feature baseline artifacts: AUC 0.8457.
- Active retrained low-burden model after rebuilding with only 18 features: AUC 0.8434.

Race should remain for now with fairness monitoring. Removing race from the low-burden model reduced AUC to 0.8411 and worsened some subgroup behavior, especially the "Other" race group FNR.

Blood pressure should remain optional. Removing BP from the low-burden screen had only a small AUC change in the ablation experiment, but BP is clinically coherent and useful when users have a measurement.

Ten-year weight change should not be required. It is clinically plausible but has poor recall reliability and high missingness.

Alcohol should be simplified to frequency. Alcohol grams and diet alcohol averages add burden and measurement noise.

Caffeine milligrams should not be required. It is hard for users to estimate accurately and is better treated as an optional trend feature.

## Supporting Artifacts

- Input reduction experiment: `results/input_reduction/input_reduction_report.md`
- Performance table: `results/input_reduction/input_reduction_performance.csv`
- Subgroup checks: `results/input_reduction/input_reduction_subgroups.csv`
- Active feature record: `features_used.txt`
