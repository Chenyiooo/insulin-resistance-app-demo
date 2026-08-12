# Model Input Mapping

This document maps the iOS app state to the current reduced LightGBM input schema.

Current active model: `reduced_lightgbm`
Current model version label in iOS: `low_burden_18_feature_v1`
Feature source of truth: `/Users/rooot/Documents/coding/Insulin-Resistance-Algorithm/data/processed/features_used.txt`

## Feature Order

The model payload uses this fixed order when a vector is needed:

1. `age`
2. `sex`
3. `race`
4. `bmi`
5. `waist_circumference`
6. `weight`
7. `height`
8. `systolic_bp`
9. `diastolic_bp`
10. `family_diabetes`
11. `hypertension_history`
12. `hypertension_med`
13. `high_cholesterol`
14. `smoking_status`
15. `alcohol_frequency`
16. `sleep_hours`
17. `gestational_diabetes`
18. `waist_height_ratio`

## Profile Inputs

| Model feature | iOS source | Encoding / unit | Missing behavior |
| --- | --- | --- | --- |
| `age` | `UserProfile.age` | Numeric years | Required |
| `sex` | `UserProfile.sexAtBirth` | Male = `1`, Female = `2` | Intersex / Prefer not to answer cannot be encoded by current binary NHANES training column, so it is marked missing |
| `race` | `UserProfile.raceEthnicity` | Mexican American = `1`, Other Hispanic = `2`, Non-Hispanic White = `3`, Non-Hispanic Black = `4`, Other / Multi-racial = `5` | Required unless Prefer not to answer |
| `height` | `heightFeet`, `heightInches` | Converted to centimeters | Required |
| `family_diabetes` | `familyHistoryDiabetes` | Yes = `1`, No = `0` | Not sure / Prefer not to answer marked missing |
| `hypertension_history` | `hypertensionHistory` | Yes = `1`, No = `0` | Not sure / Prefer not to answer marked missing |
| `hypertension_med` | `antihypertensiveMedication` | Yes = `1`, No = `0`; if no hypertension history, encoded as No | Required only when hypertension history is Yes in the UI |
| `high_cholesterol` | `highCholesterol` | Yes = `1`, No = `0` | Not sure / Prefer not to answer marked missing |
| `gestational_diabetes` | `gestationalDiabetes` | Yes = `1`, No = `0`; if not applicable, encoded as No | Required only for users assigned female at birth who have been pregnant |

Important race note: the training config currently maps `race` from NHANES `RIDRETH1`, where Asian is not a separate category. The iOS mapper therefore collapses `Non-Hispanic Asian` into code `5`. If the model is retrained with `RIDRETH3`, this should change to Asian = `6`.

## Check-In Inputs

| Model feature | iOS source | Encoding / unit | Missing behavior |
| --- | --- | --- | --- |
| `weight` | `DailyCheckIn.weight`, `weightUnit` | Converted to kilograms | Required |
| `waist_circumference` | `DailyCheckIn.waist`, `waistUnit` | Converted to centimeters | Required |
| `systolic_bp` | `DailyCheckIn.systolic` | mmHg | Optional; omitted for backend imputation when user has no recent reading |
| `diastolic_bp` | `DailyCheckIn.diastolic` | mmHg | Optional; omitted for backend imputation when user has no recent reading |
| `smoking_status` | `UserProfile.smokingStatus` | Never = `0`, Former = `1`, Current some days/every day = `2` | Prefer not to answer marked missing |
| `alcohol_frequency` | `UserProfile.alcoholFrequency` | Approximate NHANES `ALQ121` scale: never = `0`, monthly or less = `7`, 2-4/month = `6`, 2-3/week = `4`, 4+/week = `3` | Prefer not to answer marked missing |
| `sleep_hours` | `DailyCheckIn.sleepHours` or Apple Health import | Numeric hours | Required |

## Derived Inputs

| Model feature | Formula |
| --- | --- |
| `bmi` | `weight_kg / (height_cm / 100)^2` |
| `waist_height_ratio` | `waist_cm / height_cm` |

## iOS Implementation

The mapping is implemented in:

`/Users/rooot/Documents/coding/Insulin-Resistance-Algorithm/ios-app/Sources/InsulinResistanceApp/ModelInputMapper.swift`

The app exposes the current payload through:

`AppStore.currentModelInputPayload`

The payload contains:

- `features`: available model-ready numeric values keyed by model feature name
- `featureOrder`: fixed order for converting to a vector
- `orderedFeatureVector`: optional vector in model order
- `missingRequiredInputs`: required fields that cannot currently be encoded
- `omittedOptionalInputs`: optional fields intentionally left out, currently blood pressure
- `encodingNotes`: caveats such as race collapsing and optional blood pressure imputation

## Not Included In The Current Model

These app fields are useful for UX and local insights but are not part of the current 18-feature LightGBM input:

- `activeToday`
- `activityType`
- `activityDuration`
- `movementBreaks`
- `foodJournal`
- `dailyReflection`
- uploaded food photos

They can be saved locally and later used for recommendations, trend summaries, or a future expanded model, but they should not be sent as required predictors for the current reduced model.

## Backend Alignment Notes

The iOS mapper follows the feature engineering rules in:

`/Users/rooot/Documents/coding/Insulin-Resistance-Algorithm/02_build_dataset.py`

Specifically:

- Binary medical-history fields use the engineered model scale `1/0`, not raw NHANES `1/2`.
- `smoking_status` uses the engineered three-class scale `0=never`, `1=former`, `2=current`.
- `alcohol_frequency` remains on an approximate NHANES frequency-code scale because the current reduced model includes `alcohol_frequency`, not the derived `alcohol_days_per_year`.
