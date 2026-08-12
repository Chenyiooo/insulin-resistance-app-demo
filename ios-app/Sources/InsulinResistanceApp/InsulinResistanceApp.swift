import SwiftUI
import SwiftData

@main
struct InsulinResistanceApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .modelContainer(for: [StoredUserProfile.self, StoredDailyCheckIn.self])
        }
    }
}
