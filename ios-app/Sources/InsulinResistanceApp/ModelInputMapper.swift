import Foundation

struct ModelInputPayload: Codable {
    let modelName: String
    let modelVersion: String
    let featureOrder: [String]
    let features: [String: Double]
    let profileInputs: [String: Double]
    let checkInInputs: [String: Double]
    let derivedInputs: [String: Double]
    let missingRequiredInputs: [MissingDataItem]
    let omittedOptionalInputs: [String]
    let encodingNotes: [String]

    var orderedFeatureVector: [Double?] {
        featureOrder.map { features[$0] }
    }
}

enum ModelInputMapper {
    static let modelName = "reduced_lightgbm"
    static let modelVersion = "low_burden_18_feature_v1"

    static let profileInputFeatures = [
        "age", "sex", "race", "height",
        "family_diabetes", "hypertension_history",
        "hypertension_med", "high_cholesterol", "gestational_diabetes",
    ]

    static let checkInInputFeatures = [
        "weight", "waist_circumference", "systolic_bp", "diastolic_bp",
        "smoking_status", "alcohol_frequency", "sleep_hours",
    ]

    static let optionalInputFeatures = [
        "systolic_bp", "diastolic_bp",
    ]

    static let derivedInputFeatures = [
        "bmi", "waist_height_ratio",
    ]

    static let predictorFeatures = [
        "age", "sex", "race",
        "bmi", "waist_circumference", "weight", "height",
        "systolic_bp", "diastolic_bp",
        "family_diabetes", "hypertension_history", "hypertension_med", "high_cholesterol",
        "smoking_status",
        "alcohol_frequency",
        "sleep_hours",
        "gestational_diabetes",
        "waist_height_ratio",
    ]

    static func makePayload(profile: UserProfile, checkIn: DailyCheckIn) -> ModelInputPayload {
        var profileInputs: [String: Double] = [:]
        var checkInInputs: [String: Double] = [:]
        var derivedInputs: [String: Double] = [:]
        var missing: [MissingDataItem] = []
        var omittedOptional: [String] = []
        var notes: [String] = []

        assign(
            &profileInputs,
            key: "age",
            value: parseDouble(profile.age),
            missing: &missing,
            label: "Age"
        )
        assign(
            &profileInputs,
            key: "sex",
            value: sexCode(profile.sexAtBirth),
            missing: &missing,
            label: "Sex assigned at birth",
            missingCode: missingCode(for: profile.sexAtBirth)
        )
        assign(
            &profileInputs,
            key: "race",
            value: raceCode(profile.raceEthnicity),
            missing: &missing,
            label: "Race and ethnicity",
            missingCode: profile.raceEthnicity.contains("Prefer not to answer") ? MissingDataCode.preferNotToAnswer : MissingDataCode.missing
        )

        if profile.raceEthnicity.contains("Non-Hispanic Asian") {
            notes.append("race: Non-Hispanic Asian is encoded as 5 because the current training config maps race from NHANES RIDRETH1, where Asian is not separate.")
        }
        if profile.raceEthnicity.count > 1 {
            notes.append("race: multiple selections were collapsed to the first NHANES-compatible category for the current single-column model input.")
        }

        let heightCm = heightCentimeters(feet: profile.heightFeet, inches: profile.heightInches)
        assign(&profileInputs, key: "height", value: heightCm, missing: &missing, label: "Height")
        assign(
            &profileInputs,
            key: "family_diabetes",
            value: yesNoCode(profile.familyHistoryDiabetes),
            missing: &missing,
            label: "Family history of diabetes",
            missingCode: missingCode(for: profile.familyHistoryDiabetes)
        )
        assign(
            &profileInputs,
            key: "hypertension_history",
            value: yesNoCode(profile.hypertensionHistory),
            missing: &missing,
            label: "Hypertension history",
            missingCode: missingCode(for: profile.hypertensionHistory)
        )

        assign(
            &profileInputs,
            key: "hypertension_med",
            value: yesNoCode(profile.antihypertensiveMedication),
            missing: &missing,
            label: "High blood pressure medication",
            missingCode: missingCode(for: profile.antihypertensiveMedication)
        )
        assign(
            &profileInputs,
            key: "high_cholesterol",
            value: yesNoCode(profile.highCholesterol),
            missing: &missing,
            label: "High cholesterol",
            missingCode: missingCode(for: profile.highCholesterol)
        )

        let gestationalDiabetes = needsGestationalDiabetes(profile) ? profile.gestationalDiabetes : "No"
        assign(
            &profileInputs,
            key: "gestational_diabetes",
            value: yesNoCode(gestationalDiabetes),
            missing: &missing,
            label: "Gestational diabetes history",
            missingCode: missingCode(for: gestationalDiabetes)
        )

        let weightKg = weightKilograms(value: checkIn.weight, unit: checkIn.weightUnit)
        let waistCm = waistCentimeters(value: checkIn.waist, unit: checkIn.waistUnit)
        assign(&checkInInputs, key: "weight", value: weightKg, missing: &missing, label: "Weight")
        assign(&checkInInputs, key: "waist_circumference", value: waistCm, missing: &missing, label: "Waist circumference")

        if checkIn.hasRecentBloodPressure {
            assign(&checkInInputs, key: "systolic_bp", value: parseDouble(checkIn.systolic), missing: &missing, label: "Systolic blood pressure")
            assign(&checkInInputs, key: "diastolic_bp", value: parseDouble(checkIn.diastolic), missing: &missing, label: "Diastolic blood pressure")
        } else {
            omittedOptional.append("systolic_bp")
            omittedOptional.append("diastolic_bp")
            notes.append("systolic_bp and diastolic_bp are optional model inputs; when omitted, the backend preprocessor should impute them from training data.")
        }

        assign(
            &checkInInputs,
            key: "smoking_status",
            value: smokingCode(profile.smokingStatus),
            missing: &missing,
            label: "Smoking status",
            missingCode: missingCode(for: profile.smokingStatus)
        )
        assign(
            &checkInInputs,
            key: "alcohol_frequency",
            value: alcoholFrequencyCode(profile.alcoholFrequency),
            missing: &missing,
            label: "Alcohol frequency",
            missingCode: missingCode(for: profile.alcoholFrequency)
        )
        assign(&checkInInputs, key: "sleep_hours", value: parseDouble(checkIn.sleepHours), missing: &missing, label: "Sleep duration")

        if let heightCm, let weightKg, heightCm > 0 {
            derivedInputs["bmi"] = weightKg / pow(heightCm / 100, 2)
        } else {
            missing.append(MissingDataItem(field: "bmi", label: "BMI", code: MissingDataCode.missing))
        }
        if let heightCm, let waistCm, heightCm > 0 {
            derivedInputs["waist_height_ratio"] = waistCm / heightCm
        } else {
            missing.append(MissingDataItem(field: "waist_height_ratio", label: "Waist-to-height ratio", code: MissingDataCode.missing))
        }

        let features = profileInputs
            .merging(checkInInputs) { current, _ in current }
            .merging(derivedInputs) { current, _ in current }

        return ModelInputPayload(
            modelName: modelName,
            modelVersion: modelVersion,
            featureOrder: predictorFeatures,
            features: features,
            profileInputs: profileInputs,
            checkInInputs: checkInInputs,
            derivedInputs: derivedInputs,
            missingRequiredInputs: deduplicate(missing).filter { !optionalInputFeatures.contains($0.field) },
            omittedOptionalInputs: Array(Set(omittedOptional)).sorted(),
            encodingNotes: notes
        )
    }

    private static func assign(
        _ inputs: inout [String: Double],
        key: String,
        value: Double?,
        missing: inout [MissingDataItem],
        label: String,
        missingCode: String = MissingDataCode.missing
    ) {
        if let value {
            inputs[key] = value
        } else {
            missing.append(MissingDataItem(field: key, label: label, code: missingCode))
        }
    }

    private static func parseDouble(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func sexCode(_ value: String) -> Double? {
        switch value {
        case "Male":
            return 1
        case "Female":
            return 2
        default:
            return nil
        }
    }

    private static func raceCode(_ values: [String]) -> Double? {
        if values.isEmpty || values.contains("Prefer not to answer") {
            return nil
        }

        let priority = [
            "Mexican American",
            "Other Hispanic",
            "Non-Hispanic White",
            "Non-Hispanic Black",
            "Non-Hispanic Asian",
            "Another race or ethnicity",
        ]
        guard let selected = priority.first(where: { values.contains($0) }) else {
            return nil
        }

        switch selected {
        case "Mexican American":
            return 1
        case "Other Hispanic":
            return 2
        case "Non-Hispanic White":
            return 3
        case "Non-Hispanic Black":
            return 4
        default:
            return 5
        }
    }

    private static func yesNoCode(_ value: String) -> Double? {
        switch value {
        case "Yes":
            return 1
        case "No":
            return 0
        default:
            return nil
        }
    }

    private static func smokingCode(_ value: String) -> Double? {
        switch value {
        case "Never smoked":
            return 0
        case "Formerly smoked":
            return 1
        case "Currently smoke some days":
            return 2
        case "Currently smoke every day":
            return 2
        default:
            return nil
        }
    }

    private static func alcoholFrequencyCode(_ value: String) -> Double? {
        switch value {
        case "Never in the past 12 months":
            return 0
        case "Monthly or less":
            return 7
        case "2-4 times a month":
            return 6
        case "2-3 times a week":
            return 4
        case "4 or more times a week":
            return 3
        default:
            return nil
        }
    }

    private static func heightCentimeters(feet: String, inches: String) -> Double? {
        guard let feetValue = parseDouble(feet), let inchesValue = parseDouble(inches) else {
            return nil
        }
        let totalInches = feetValue * 12 + inchesValue
        guard totalInches > 0 else { return nil }
        return totalInches * 2.54
    }

    private static func weightKilograms(value: String, unit: String) -> Double? {
        guard let weight = parseDouble(value), weight > 0 else { return nil }
        return unit == "kg" ? weight : weight * 0.45359237
    }

    private static func waistCentimeters(value: String, unit: String) -> Double? {
        guard let waist = parseDouble(value), waist > 0 else { return nil }
        return unit == "cm" ? waist : waist * 2.54
    }

    private static func needsGestationalDiabetes(_ profile: UserProfile) -> Bool {
        profile.sexAtBirth == "Female" && profile.hasBeenPregnant == "Yes"
    }

    private static func missingCode(for value: String) -> String {
        switch value {
        case "Prefer not to answer":
            return MissingDataCode.preferNotToAnswer
        case "Not sure":
            return MissingDataCode.notSure
        default:
            return MissingDataCode.missing
        }
    }

    private static func deduplicate(_ items: [MissingDataItem]) -> [MissingDataItem] {
        var seen: Set<String> = []
        return items.filter { item in
            if seen.contains(item.field) {
                return false
            }
            seen.insert(item.field)
            return true
        }
    }
}
