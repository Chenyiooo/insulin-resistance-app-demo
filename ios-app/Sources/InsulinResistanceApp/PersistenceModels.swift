import Foundation
import SwiftData

struct MissingDataItem: Codable, Identifiable {
    var id: String { field }
    let field: String
    let label: String
    let code: String
}

enum MissingDataCode {
    static let missing = "missing"
    static let preferNotToAnswer = "prefer_not_to_answer"
    static let notSure = "not_sure"
    static let noRecentReading = "no_recent_reading"
}

enum MissingDataCodec {
    static func encode(_ items: [MissingDataItem]) -> String {
        guard let data = try? JSONEncoder().encode(items) else {
            return "[]"
        }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func decode(_ json: String) -> [MissingDataItem] {
        guard let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([MissingDataItem].self, from: data) else {
            return []
        }
        return items
    }
}

@Model
final class StoredUserProfile {
    var name: String
    var age: String
    var sexAtBirth: String
    var hasBeenPregnant: String
    var gestationalDiabetes: String
    var raceEthnicityJSON: String
    var heightFeet: String
    var heightInches: String
    var familyHistoryDiabetes: String
    var hypertensionHistory: String
    var antihypertensiveMedication: String
    var highCholesterol: String
    var smokingStatus: String
    var alcoholFrequency: String
    var missingDataJSON: String
    var updatedAt: Date

    init(profile: UserProfile, missingItems: [MissingDataItem]) {
        self.name = profile.name
        self.age = profile.age
        self.sexAtBirth = profile.sexAtBirth
        self.hasBeenPregnant = profile.hasBeenPregnant
        self.gestationalDiabetes = profile.gestationalDiabetes
        self.raceEthnicityJSON = Self.encodeStrings(profile.raceEthnicity)
        self.heightFeet = profile.heightFeet
        self.heightInches = profile.heightInches
        self.familyHistoryDiabetes = profile.familyHistoryDiabetes
        self.hypertensionHistory = profile.hypertensionHistory
        self.antihypertensiveMedication = profile.antihypertensiveMedication
        self.highCholesterol = profile.highCholesterol
        self.smokingStatus = profile.smokingStatus
        self.alcoholFrequency = profile.alcoholFrequency
        self.missingDataJSON = MissingDataCodec.encode(missingItems)
        self.updatedAt = Date()
    }

    func update(from profile: UserProfile, missingItems: [MissingDataItem]) {
        name = profile.name
        age = profile.age
        sexAtBirth = profile.sexAtBirth
        hasBeenPregnant = profile.hasBeenPregnant
        gestationalDiabetes = profile.gestationalDiabetes
        raceEthnicityJSON = Self.encodeStrings(profile.raceEthnicity)
        heightFeet = profile.heightFeet
        heightInches = profile.heightInches
        familyHistoryDiabetes = profile.familyHistoryDiabetes
        hypertensionHistory = profile.hypertensionHistory
        antihypertensiveMedication = profile.antihypertensiveMedication
        highCholesterol = profile.highCholesterol
        smokingStatus = profile.smokingStatus
        alcoholFrequency = profile.alcoholFrequency
        missingDataJSON = MissingDataCodec.encode(missingItems)
        updatedAt = Date()
    }

    var userProfile: UserProfile {
        UserProfile(
            name: name,
            age: age,
            sexAtBirth: sexAtBirth,
            hasBeenPregnant: hasBeenPregnant,
            gestationalDiabetes: gestationalDiabetes,
            raceEthnicity: Self.decodeStrings(raceEthnicityJSON),
            heightFeet: heightFeet,
            heightInches: heightInches,
            familyHistoryDiabetes: familyHistoryDiabetes,
            hypertensionHistory: hypertensionHistory,
            antihypertensiveMedication: antihypertensiveMedication,
            highCholesterol: highCholesterol,
            smokingStatus: smokingStatus,
            alcoholFrequency: alcoholFrequency
        )
    }

    private static func encodeStrings(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func decodeStrings(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }
}

@Model
final class StoredDailyCheckIn {
    var checkInDate: Date
    var weight: String
    var weightUnit: String
    var waist: String
    var waistUnit: String
    var systolic: String
    var diastolic: String
    var bloodPressureDate: String
    var hasRecentBloodPressure: Bool
    var sleepHours: String
    var activeToday: String
    var activityType: String
    var activityDuration: String
    var movementBreaks: String
    var foodJournal: String
    var dailyReflection: String
    var isCompleted: Bool
    var missingDataJSON: String
    var updatedAt: Date

    init(checkIn: DailyCheckIn, missingItems: [MissingDataItem]) {
        self.checkInDate = Calendar.current.startOfDay(for: Date())
        self.weight = checkIn.weight
        self.weightUnit = checkIn.weightUnit
        self.waist = checkIn.waist
        self.waistUnit = checkIn.waistUnit
        self.systolic = checkIn.systolic
        self.diastolic = checkIn.diastolic
        self.bloodPressureDate = checkIn.bloodPressureDate
        self.hasRecentBloodPressure = checkIn.hasRecentBloodPressure
        self.sleepHours = checkIn.sleepHours
        self.activeToday = Self.encodeBool(checkIn.activeToday)
        self.activityType = checkIn.activityType
        self.activityDuration = checkIn.activityDuration
        self.movementBreaks = checkIn.movementBreaks
        self.foodJournal = checkIn.foodJournal
        self.dailyReflection = checkIn.dailyReflection
        self.isCompleted = checkIn.isCompleted
        self.missingDataJSON = MissingDataCodec.encode(missingItems)
        self.updatedAt = Date()
    }

    func update(from checkIn: DailyCheckIn, missingItems: [MissingDataItem]) {
        weight = checkIn.weight
        weightUnit = checkIn.weightUnit
        waist = checkIn.waist
        waistUnit = checkIn.waistUnit
        systolic = checkIn.systolic
        diastolic = checkIn.diastolic
        bloodPressureDate = checkIn.bloodPressureDate
        hasRecentBloodPressure = checkIn.hasRecentBloodPressure
        sleepHours = checkIn.sleepHours
        activeToday = Self.encodeBool(checkIn.activeToday)
        activityType = checkIn.activityType
        activityDuration = checkIn.activityDuration
        movementBreaks = checkIn.movementBreaks
        foodJournal = checkIn.foodJournal
        dailyReflection = checkIn.dailyReflection
        isCompleted = checkIn.isCompleted
        missingDataJSON = MissingDataCodec.encode(missingItems)
        updatedAt = Date()
    }

    var dailyCheckIn: DailyCheckIn {
        DailyCheckIn(
            weight: weight,
            weightUnit: weightUnit,
            waist: waist,
            waistUnit: waistUnit,
            systolic: systolic,
            diastolic: diastolic,
            bloodPressureDate: bloodPressureDate,
            hasRecentBloodPressure: hasRecentBloodPressure,
            sleepHours: sleepHours,
            activeToday: Self.decodeBool(activeToday),
            activityType: activityType,
            activityDuration: activityDuration,
            movementBreaks: movementBreaks,
            foodJournal: foodJournal,
            dailyReflection: dailyReflection,
            isCompleted: isCompleted
        )
    }

    private static func encodeBool(_ value: Bool?) -> String {
        guard let value else { return "" }
        return value ? "yes" : "no"
    }

    private static func decodeBool(_ value: String) -> Bool? {
        if value == "yes" { return true }
        if value == "no" { return false }
        return nil
    }
}
