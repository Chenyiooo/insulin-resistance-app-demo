import Foundation
import SwiftData
import SwiftUI

enum AppScreen {
    case welcome
    case profile
    case main
    case checkInEntry
    case manualCheckIn
    case aiCheckIn
    case completion
    case activityInsight
}

enum AppTab: String, CaseIterable {
    case cloudy = "Cloudy"
    case log = "Log"
    case home = "Home"
    case progress = "Progress"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .cloudy: "cloud"
        case .log: "plus.circle"
        case .home: "house"
        case .progress: "chart.bar"
        case .profile: "person.circle"
        }
    }
}

final class AppStore: ObservableObject {
    @Published var screen: AppScreen = .welcome
    @Published var selectedTab: AppTab = .home
    @Published var profile = MockData.profile
    @Published var checkIn = MockData.checkIn
    @Published var weeklyRisk = MockData.weeklyRisk
    private var hasLoadedPersistedData = false

    func showMain(tab: AppTab = .home) {
        selectedTab = tab
        screen = .main
    }

    func startCheckIn() {
        selectedTab = .log
        screen = .checkInEntry
    }

    func completeCheckIn() {
        checkIn.isCompleted = true
        screen = .completion
    }

    func loadPersistedDataIfNeeded(profile: StoredUserProfile?, checkIn: StoredDailyCheckIn?) {
        guard !hasLoadedPersistedData else { return }
        if let profile {
            self.profile = profile.userProfile
        }
        if let checkIn {
            self.checkIn = checkIn.dailyCheckIn
        }
        hasLoadedPersistedData = true
    }

    func loadPersistedDataIfNeeded(from context: ModelContext) {
        guard !hasLoadedPersistedData else { return }
        let profileDescriptor = FetchDescriptor<StoredUserProfile>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let checkInDescriptor = FetchDescriptor<StoredDailyCheckIn>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let profile = try? context.fetch(profileDescriptor).first
        let checkIn = try? context.fetch(checkInDescriptor).first
        loadPersistedDataIfNeeded(profile: profile, checkIn: checkIn)
    }

    func saveProfile(in context: ModelContext) {
        let missingItems = profileMissingDataItems()
        let descriptor = FetchDescriptor<StoredUserProfile>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.update(from: profile, missingItems: missingItems)
        } else {
            context.insert(StoredUserProfile(profile: profile, missingItems: missingItems))
        }
        try? context.save()
    }

    func saveCheckIn(in context: ModelContext) {
        let missingItems = checkInMissingDataItems()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<StoredDailyCheckIn>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let existing = (try? context.fetch(descriptor))?
            .first { Calendar.current.isDate($0.checkInDate, inSameDayAs: startOfToday) }
        if let existing {
            existing.update(from: checkIn, missingItems: missingItems)
        } else {
            context.insert(StoredDailyCheckIn(checkIn: checkIn, missingItems: missingItems))
        }
        try? context.save()
    }

    func profileMissingDataItems() -> [MissingDataItem] {
        var items: [MissingDataItem] = []
        addRequiredString(&items, field: "age", label: "Age", value: profile.age)
        addRequiredChoice(&items, field: "sex_at_birth", label: "Sex assigned at birth", value: profile.sexAtBirth)
        if profile.sexAtBirth == "Female" {
            addRequiredChoice(&items, field: "pregnancy_history", label: "Pregnancy history", value: profile.hasBeenPregnant)
            if profile.hasBeenPregnant == "Yes" {
                addRequiredChoice(&items, field: "gestational_diabetes", label: "Gestational diabetes history", value: profile.gestationalDiabetes)
            }
        }
        if profile.raceEthnicity.isEmpty {
            items.append(MissingDataItem(field: "race_ethnicity", label: "Race and ethnicity", code: MissingDataCode.missing))
        } else if profile.raceEthnicity.contains("Prefer not to answer") {
            items.append(MissingDataItem(field: "race_ethnicity", label: "Race and ethnicity", code: MissingDataCode.preferNotToAnswer))
        }
        addRequiredString(&items, field: "height_feet", label: "Height feet", value: profile.heightFeet)
        addRequiredString(&items, field: "height_inches", label: "Height inches", value: profile.heightInches)
        addRequiredChoice(&items, field: "family_history_diabetes", label: "Family history of diabetes", value: profile.familyHistoryDiabetes)
        addRequiredChoice(&items, field: "hypertension_history", label: "Hypertension history", value: profile.hypertensionHistory)
        if profile.hypertensionHistory == "Yes" {
            addRequiredChoice(&items, field: "antihypertensive_medication", label: "High blood pressure medication", value: profile.antihypertensiveMedication)
        }
        addRequiredChoice(&items, field: "high_cholesterol", label: "High cholesterol", value: profile.highCholesterol)
        addRequiredChoice(&items, field: "smoking_status", label: "Smoking status", value: profile.smokingStatus)
        addRequiredChoice(&items, field: "alcohol_frequency", label: "Alcohol frequency", value: profile.alcoholFrequency)
        return items
    }

    func checkInMissingDataItems() -> [MissingDataItem] {
        var items: [MissingDataItem] = []
        addRequiredString(&items, field: "weight", label: "Weight", value: checkIn.weight)
        addRequiredString(&items, field: "waist_circumference", label: "Waist circumference", value: checkIn.waist)
        if !checkIn.hasRecentBloodPressure {
            items.append(MissingDataItem(field: "blood_pressure", label: "Blood pressure", code: MissingDataCode.noRecentReading))
        } else {
            addRequiredString(&items, field: "systolic_bp", label: "Systolic blood pressure", value: checkIn.systolic)
            addRequiredString(&items, field: "diastolic_bp", label: "Diastolic blood pressure", value: checkIn.diastolic)
            addRequiredString(&items, field: "blood_pressure_date", label: "Blood pressure date measured", value: checkIn.bloodPressureDate)
        }
        addRequiredString(&items, field: "sleep_hours", label: "Sleep duration", value: checkIn.sleepHours)
        if checkIn.activeToday == nil {
            items.append(MissingDataItem(field: "physical_activity_today", label: "Physical activity", code: MissingDataCode.missing))
        } else if checkIn.activeToday == true {
            addRequiredString(&items, field: "activity_type", label: "Activity type", value: checkIn.activityType)
            addRequiredString(&items, field: "activity_duration", label: "Activity duration", value: checkIn.activityDuration)
        }
        addRequiredChoice(&items, field: "movement_breaks", label: "Movement breaks", value: checkIn.movementBreaks)
        return items
    }

    private func addRequiredString(_ items: inout [MissingDataItem], field: String, label: String, value: String) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(MissingDataItem(field: field, label: label, code: MissingDataCode.missing))
        }
    }

    private func addRequiredChoice(_ items: inout [MissingDataItem], field: String, label: String, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            items.append(MissingDataItem(field: field, label: label, code: MissingDataCode.missing))
        } else if trimmed == "Prefer not to answer" {
            items.append(MissingDataItem(field: field, label: label, code: MissingDataCode.preferNotToAnswer))
        } else if trimmed == "Not sure" {
            items.append(MissingDataItem(field: field, label: label, code: MissingDataCode.notSure))
        }
    }

    func importMockAppleHealthData() {
        checkIn.weight = "146"
        checkIn.systolic = "118"
        checkIn.diastolic = "76"
        checkIn.sleepHours = "7.2"
        checkIn.activeToday = true
        checkIn.activityType = "Brisk walking"
        checkIn.activityDuration = "25"
        checkIn.movementBreaks = "A few times during the day"
    }
}

struct UserProfile {
    var name: String
    var age: String
    var sexAtBirth: String
    var hasBeenPregnant: String
    var gestationalDiabetes: String
    var raceEthnicity: [String]
    var heightFeet: String
    var heightInches: String
    var familyHistoryDiabetes: String
    var hypertensionHistory: String
    var antihypertensiveMedication: String
    var highCholesterol: String
    var smokingStatus: String
    var alcoholFrequency: String
}

struct DailyCheckIn {
    var weight: String
    var weightUnit: String
    var waist: String
    var waistUnit: String
    var systolic: String
    var diastolic: String
    var bloodPressureDate: String
    var hasRecentBloodPressure: Bool
    var sleepHours: String
    var activeToday: Bool?
    var activityType: String
    var activityDuration: String
    var movementBreaks: String
    var foodJournal: String
    var dailyReflection: String
    var isCompleted: Bool
}

struct WeeklyRisk {
    var score: Int
    var band: String
    var increasing: [String]
    var decreasing: [String]
}

enum MockData {
    static let profile = UserProfile(
        name: "Chenyi",
        age: "34",
        sexAtBirth: "Female",
        hasBeenPregnant: "Yes",
        gestationalDiabetes: "No",
        raceEthnicity: ["Asian"],
        heightFeet: "5",
        heightInches: "6",
        familyHistoryDiabetes: "Not sure",
        hypertensionHistory: "No",
        antihypertensiveMedication: "No",
        highCholesterol: "Not sure",
        smokingStatus: "Never smoked",
        alcoholFrequency: "Never in the past 12 months"
    )

    static let checkIn = DailyCheckIn(
        weight: "148",
        weightUnit: "lb",
        waist: "33",
        waistUnit: "in",
        systolic: "122",
        diastolic: "78",
        bloodPressureDate: "Today",
        hasRecentBloodPressure: true,
        sleepHours: "6",
        activeToday: true,
        activityType: "Brisk walking",
        activityDuration: "18",
        movementBreaks: "A few times during the day",
        foodJournal: "Added",
        dailyReflection: "",
        isCompleted: false
    )

    static let weeklyRisk = WeeklyRisk(
        score: 64,
        band: "High Risk",
        increasing: ["Waist circumference", "BMI", "High blood pressure history"],
        decreasing: ["Younger age", "Typical sleep duration"]
    )
}
