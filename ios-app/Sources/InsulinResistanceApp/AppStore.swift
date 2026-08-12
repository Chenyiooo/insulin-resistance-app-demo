import Foundation
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
}

struct UserProfile {
    var name: String
    var age: String
    var sexAtBirth: String
    var hasBeenPregnant: Bool
    var gestationalDiabetes: String
    var raceEthnicity: [String]
    var heightFeet: String
    var heightInches: String
}

struct DailyCheckIn {
    var weight: String
    var waist: String
    var systolic: String
    var diastolic: String
    var smokedToday: Bool?
    var drankAlcoholToday: Bool?
    var sleepHours: String
    var activeToday: Bool?
    var activityType: String
    var activityDuration: String
    var movementBreaks: String
    var foodJournal: String
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
        hasBeenPregnant: true,
        gestationalDiabetes: "No",
        raceEthnicity: ["Asian"],
        heightFeet: "5",
        heightInches: "6"
    )

    static let checkIn = DailyCheckIn(
        weight: "148",
        waist: "33",
        systolic: "122",
        diastolic: "78",
        smokedToday: false,
        drankAlcoholToday: false,
        sleepHours: "6",
        activeToday: true,
        activityType: "Brisk walking",
        activityDuration: "18",
        movementBreaks: "A few times",
        foodJournal: "Added",
        isCompleted: false
    )

    static let weeklyRisk = WeeklyRisk(
        score: 64,
        band: "High Risk",
        increasing: ["Waist circumference", "BMI", "High blood pressure history"],
        decreasing: ["Younger age", "Typical sleep duration"]
    )
}
