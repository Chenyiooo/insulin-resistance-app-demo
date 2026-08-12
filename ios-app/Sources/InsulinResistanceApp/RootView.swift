import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            switch store.screen {
            case .welcome:
                WelcomeView()
            case .profile:
                ProfileSetupView()
            case .main:
                MainTabView()
            case .checkInEntry:
                CheckInEntryView()
            case .manualCheckIn:
                ManualCheckInView()
            case .aiCheckIn:
                AICheckInView()
            case .completion:
                CompletionView()
            case .activityInsight:
                ActivityInsightView()
            }
        }
        .onAppear {
            store.loadPersistedDataIfNeeded(from: modelContext)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch store.selectedTab {
                case .cloudy:
                    CloudyHomeView()
                case .log:
                    CheckInEntryView(showTabBar: false)
                case .home:
                    HomeView()
                case .progress:
                    ProgressDashboardView()
                case .profile:
                    ProfileSetupView(isModalFlow: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomTabBar()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct BottomTabBar: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    if tab == .log {
                        store.startCheckIn()
                    } else {
                        store.showMain(tab: tab)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 28, weight: .regular))
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundStyle(store.selectedTab == tab ? AppColor.blue : AppColor.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColor.line)
                .frame(height: 1)
        }
    }
}
