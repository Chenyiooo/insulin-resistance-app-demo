import Foundation
import UserNotifications

enum CheckInReminderService {
    private static let identifierPrefix = "daily-checkin-reminder-"
    private static let scheduledDayCount = 30

    static func refresh(isTodayComplete: Bool) {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            var isAuthorized = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional

            if settings.authorizationStatus == .notDetermined {
                isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
            }
            guard isAuthorized else { return }

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let dates = (0..<scheduledDayCount).compactMap {
                calendar.date(byAdding: .day, value: $0, to: today)
            }
            center.removePendingNotificationRequests(withIdentifiers: dates.map(identifier(for:)))

            for date in dates {
                if calendar.isDate(date, inSameDayAs: today), isTodayComplete {
                    continue
                }
                guard let reminderDate = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date),
                      reminderDate > Date() else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Daily check-in reminder"
                content.body = "Please complete today's check-in when you have a moment."
                content.sound = .default

                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: reminderDate
                )
                let request = UNNotificationRequest(
                    identifier: identifier(for: date),
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                try? await center.add(request)
            }
        }
    }

    static func markTodayComplete() {
        let todayIdentifier = identifier(for: Calendar.current.startOfDay(for: Date()))
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [todayIdentifier]
        )
    }

    static func clearScheduledReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(identifierPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: identifiers
            )
        }
    }

    private static func identifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return identifierPrefix + formatter.string(from: date)
    }
}
