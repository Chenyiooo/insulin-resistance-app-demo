import SwiftUI

struct CheckInEntryView: View {
    @EnvironmentObject private var store: AppStore
    var showTabBar = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    HStack {
                        Text("Log")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppColor.muted)
                        Spacer()
                    }
                    .padding(.top, 28)

                    CloudyMascotView(size: 240)
                        .padding(.top, 34)

                    if store.checkIn.isCompleted {
                        completedCheckInContent
                    } else {
                        VStack(spacing: 12) {
                            Text("How would you like to check in?")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.center)
                            Text("Choose a method to log today's sleep, habits, activity, and optional food journal.")
                                .font(.title3)
                                .foregroundStyle(AppColor.muted)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                        }

                        methodChoices

                        Text("You can switch methods at any time · About 3-5 min")
                            .font(.callout)
                            .foregroundStyle(AppColor.muted)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showTabBar {
                BottomTabBar()
            }
        }
        .background(.white)
    }

    private var completedCheckInContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                Label("Completed today", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("View today's summary or update anything you logged.")
                    .font(.title3)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }

            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Summary")
                        .font(.headline)
                        .foregroundStyle(AppColor.text)
                    summaryRow(icon: "moon.zzz", label: "Sleep", value: loggedValue(store.checkIn.sleepHours, suffix: "hr"))
                    summaryRow(icon: "figure.walk", label: "Activity", value: activitySummary)
                    summaryRow(icon: "figure.stand", label: "Movement breaks", value: emptyFallback(store.checkIn.movementBreaks))
                    summaryRow(icon: "fork.knife", label: "Food journal", value: store.checkIn.foodJournalSummary)
                }
            }

            PrimaryButton(title: "View Today's Summary") {
                store.viewTodaySummary()
            }

            OutlineButton(title: "Update Check-in") {
                store.screen = .manualCheckIn
            }
        }
    }

    private var methodChoices: some View {
        VStack(spacing: 18) {
            MethodCard(
                icon: "bubble.left.and.bubble.right",
                title: "Talk to Cloudy",
                subtitle: "Share by text",
                badge: "Conversational",
                isHighlighted: true
            ) {
                store.screen = .aiCheckIn
            }

            MethodCard(
                icon: "checklist",
                title: "Manual Input",
                subtitle: "Complete a guided form",
                badge: "Step by step",
                isHighlighted: false
            ) {
                store.screen = .manualCheckIn
            }
        }
    }

    private var activitySummary: String {
        if store.checkIn.activeToday == false {
            return "No activity today"
        }
        return loggedValue(store.checkIn.activityDuration, suffix: "min")
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppColor.blue)
                .frame(width: 24)
            Text(label)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AppColor.text)
            Spacer()
            Text(value)
                .font(.callout)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.trailing)
        }
    }

    private func loggedValue(_ value: String, suffix: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not logged" : "\(trimmed) \(suffix)"
    }

    private func emptyFallback(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not logged" : trimmed
    }
}

struct MethodCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String
    let isHighlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 22) {
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(isHighlighted ? Color(red: 0.12, green: 0.30, blue: 0.70) : AppColor.muted)
                    .frame(width: 76)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title.bold())
                        .foregroundStyle(isHighlighted ? Color(red: 0.04, green: 0.20, blue: 0.50) : .black)
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(AppColor.muted)
                    Text(badge)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isHighlighted ? Color.blue.opacity(0.10) : Color.gray.opacity(0.12))
                        .foregroundStyle(isHighlighted ? AppColor.blue : AppColor.muted)
                        .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title)
                    .foregroundStyle(isHighlighted ? Color(red: 0.12, green: 0.30, blue: 0.70) : AppColor.muted)
            }
            .padding(22)
            .background(isHighlighted ? AppColor.sky : .white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isHighlighted ? Color.blue.opacity(0.35) : AppColor.line))
        }
        .buttonStyle(.plain)
    }
}
