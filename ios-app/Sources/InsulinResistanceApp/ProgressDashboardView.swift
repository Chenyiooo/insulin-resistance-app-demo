import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedSegment = 0
    #if DEBUG && targetEnvironment(simulator)
    @State private var previewDays: Int?
    #endif

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Progress")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppColor.text)
                        .padding(.top, 24)

                    Picker("Progress section", selection: $selectedSegment) {
                        Text("Daily Insights").tag(0)
                        Text("Weekly Risk & Trends").tag(1)
                    }
                    .pickerStyle(.segmented)

                    #if DEBUG && targetEnvironment(simulator)
                    if selectedSegment == 1 {
                        HStack {
                            Text("Simulator preview")
                                .font(.footnote.weight(.semibold))
                            Spacer()
                            Button("6 days") { previewDays = 6 }
                            Button("7 days") { previewDays = 7 }
                            Button("14 days") { previewDays = 14 }
                            if previewDays != nil {
                                Button("End") { previewDays = nil }
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(AppColor.blue)
                    }
                    #endif

                    if selectedSegment == 0 {
                        PredictionStatusBanner(
                            mode: store.riskPredictionMode,
                            actionTitle: store.hasMissingRequiredData ? "Complete missing info" : nil
                        ) {
                            store.completeMissingRequiredInput()
                        }
                    }

                    if selectedSegment == 0 {
                        DailyInsightsView()
                    } else {
                        #if DEBUG && targetEnvironment(simulator)
                        WeeklyRiskView(previewDays: previewDays)
                        #else
                        WeeklyRiskView()
                        #endif
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.white)
        .onAppear {
            if store.hasNewWeeklyFeedbackToday {
                selectedSegment = 1
            }
        }
    }
}

struct PredictionStatusBanner: View {
    let mode: RiskPredictionMode
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.text)
                if let detail = mode.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }
        }
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var icon: String {
        switch mode {
        case .remoteModel:
            return "checkmark.seal"
        case .loadingRemote:
            return "arrow.triangle.2.circlepath"
        case .localFallback:
            return "desktopcomputer"
        case .unavailable:
            return "exclamationmark.triangle"
        }
    }

    private var color: Color {
        switch mode {
        case .remoteModel:
            return .green
        case .loadingRemote:
            return AppColor.blue
        case .localFallback:
            return AppColor.blue
        case .unavailable:
            return .orange
        }
    }
}

struct DailyInsightsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundStyle(AppColor.blue)
                Spacer()
                Text("Today · \(Self.dayFormatter.string(from: Date()))")
                    .font(.headline)
                    .foregroundStyle(AppColor.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColor.blue)
            }

            SectionCard {
                HStack(spacing: 18) {
                    CloudyMascotView(size: 100)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today's check-in")
                            .font(.headline)
                            .foregroundStyle(AppColor.blue)
                        Text("Here's a summary of what you logged and a few suggestions based on today's data.")
                            .font(.callout)
                            .foregroundStyle(AppColor.text)
                    }
                    Spacer()
                }
            }
            .background(AppColor.sky)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SummaryTile(icon: "moon.zzz", title: "Sleep", value: loggedValue(store.checkIn.sleepHours, suffix: "hr"))
                SummaryTile(icon: "figure.walk", title: "Moderate activity", value: loggedValue(store.checkIn.activityDuration, suffix: "min"))
                SummaryTile(icon: "figure.stand", title: "Movement breaks", value: emptyFallback(store.checkIn.movementBreaks))
                SummaryTile(icon: "fork.knife", title: "Food journal", value: store.checkIn.foodJournalSummary)
            }

            Text("Suggestions for today")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(store.dailyInsights.enumerated()), id: \.element.id) { index, insight in
                    SuggestionRow(insight: insight) {
                        store.selectedDailyInsightTitle = insight.title
                        store.screen = .activityInsight
                    }
                    if index < store.dailyInsights.count - 1 {
                        Divider()
                    }
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))

            Text("Suggestions support general wellness and are not medical advice.")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)

            Text("Insight source: \(store.dailyInsightsSource)")
                .font(.caption2)
                .foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    private func loggedValue(_ value: String, suffix: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not logged" : "\(trimmed) \(suffix)"
    }

    private func emptyFallback(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not logged" : trimmed
    }
}

struct WeeklyRiskView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTrend: WeeklyTrendMetric?
    private var periodCheckIns: [StoredDailyCheckIn] {
        (store.weeklyFeedback?.periodCheckIns ?? []).compactMap { item in
            guard let date = Self.checkInDate(item.checkInDate) else { return nil }
            let record = StoredDailyCheckIn(checkIn: item.data, missingItems: [])
            record.checkInDate = date
            return record
        }
    }
    #if DEBUG && targetEnvironment(simulator)
    var previewDays: Int? = nil

    private var displayedCheckIns: [StoredDailyCheckIn] {
        guard let previewDays else { return periodCheckIns }
        return (0..<previewDays).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset - previewDays + 1, to: Date()) else { return nil }
            var sample = store.checkIn
            sample.isCompleted = true
            let record = StoredDailyCheckIn(checkIn: sample, missingItems: [])
            record.checkInDate = Calendar.current.startOfDay(for: date)
            return record
        }
    }
    #else
    private var displayedCheckIns: [StoredDailyCheckIn] { periodCheckIns }
    #endif

    private var completedDayCount: Int {
        WeeklyHistorySummary.completedUniqueDayCount(displayedCheckIns)
    }

    private var hasEnoughWeeklyData: Bool {
        isPreviewing ? completedDayCount >= 7 : store.weeklyFeedback?.status == "ready"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            #if DEBUG && targetEnvironment(simulator)
            if previewDays != nil {
                Text("SIMULATED HISTORY - not saved or uploaded. This previews the layout only; it does not generate a risk estimate.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            #endif
            Text(feedbackTitle)
                .font(.headline)
                .foregroundStyle(AppColor.text)

            if !hasEnoughWeeklyData {
                weeklyDataEmptyState
            } else {
                weeklyRiskContent
            }
        }
        .sheet(item: $selectedTrend) { metric in
            WeeklyTrendDetailView(metric: metric, periodCheckIns: displayedCheckIns)
                .environmentObject(store)
        }
        .task {
            await store.refreshWeeklyFeedback()
        }
    }

    private var weeklyDataEmptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Weekly feedback is not ready yet", systemImage: "calendar.badge.clock")
                        .font(.title3.bold())
                        .foregroundStyle(AppColor.text)
                    Text("Feedback is available after \(store.weeklyFeedback?.requiredDays ?? 7) consecutive completed check-ins from your first day.")
                        .font(.callout)
                        .foregroundStyle(AppColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(isPreviewing
                         ? "\(completedDayCount) completed days in simulator preview."
                         : "\(store.weeklyFeedback?.completedDays ?? completedDayCount) of \(store.weeklyFeedback?.requiredDays ?? 7) completed days for this feedback period.")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppColor.blue)
                    Text(isPreviewing ? "Select 7 or 14 days above to inspect the layout." : "The estimate appears after every day in the period has a completed check-in.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .background(AppColor.sky)

            Text(isPreviewing ? "Preview records exist only on this screen." : "Weekly trends will use real saved check-ins only.")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var weeklyRiskContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let feedback = store.weeklyFeedback, let result = feedback.riskResult, !isPreviewing {
                Text("Based on \(feedback.milestoneDay ?? 7) consecutive completed days. Daily measurements are averaged; profile answers use the latest answers in that period.")
                    .font(.callout)
                    .foregroundStyle(AppColor.muted)
                if let sleep = feedback.averagedFeatures["sleep_hours"] {
                    Text(String(format: "Average sleep: %.1f hr (%d days)", sleep, feedback.measurementCounts["sleep_hours"] ?? 0))
                        .font(.callout)
                }
                if let weight = feedback.averagedFeatures["weight"] {
                    Text(String(format: "Average weight: %.1f kg (%d measured days)", weight, feedback.measurementCounts["weight"] ?? 0))
                        .font(.callout)
                }
                if let waist = feedback.averagedFeatures["waist_circumference"] {
                    Text(String(format: "Average waist: %.1f cm (%d measured days)", waist, feedback.measurementCounts["waist_circumference"] ?? 0))
                        .font(.callout)
                }
            SectionCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.band)
                                .font(.title2.bold())
                                .foregroundStyle(AppColor.blue)
                            Text("\(result.percent)% estimated risk")
                                .font(.headline)
                                .foregroundStyle(AppColor.text)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.15), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: CGFloat(result.percent) / 100)
                                .stroke(AppColor.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(result.percent)%")
                                .font(.headline)
                                .foregroundStyle(AppColor.blue)
                        }
                        .frame(width: 72, height: 72)
                    }

                    Slider(value: .constant(Double(result.percent)), in: 0...100)
                        .tint(AppColor.blue)
                        .disabled(true)

                    Text(riskComparisonText(result.percent))
                        .font(.callout)
                        .foregroundStyle(AppColor.text)
                    Text("This is a screening estimate, not a diagnosis.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }

            Text("What influenced this estimate")
                .font(.headline)

            SectionCard {
                FactorList(
                    title: "Increasing estimate",
                    icon: "arrow.up.circle",
                    color: .red,
                    factors: result.increasingFactors
                )
                Divider().padding(.vertical, 8)
                FactorList(
                    title: "Decreasing estimate",
                    icon: "arrow.down.circle",
                    color: .green,
                    factors: result.decreasingFactors
                )
            }
            } else {
                SectionCard {
                    Text(isPreviewing ? "Preview only. No simulated risk percentage is shown." : "The period has enough records, but its model estimate is unavailable. Please try again later.")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)
                }
            }

            Text("Explore weekly trends")
                .font(.headline)

            VStack(spacing: 0) {
                TrendRow(metric: .sleep) {
                    selectedTrend = .sleep
                }
                Divider()
                TrendRow(metric: .activity) {
                    selectedTrend = .activity
                }
                Divider()
                TrendRow(metric: .movementBreaks) {
                    selectedTrend = .movementBreaks
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
        }
    }

    private func riskComparisonText(_ score: Int) -> String {
        let cutoff = 65
        if score >= cutoff {
            return "Your estimate is \(score - cutoff) percentage points above the high-risk cutoff."
        }
        return "Your estimate is \(cutoff - score) percentage points below the high-risk cutoff."
    }

    private var feedbackTitle: String {
        if isPreviewing { return "Day \(completedDayCount) preview" }
        if let day = store.weeklyFeedback?.milestoneDay { return "Day \(day) feedback" }
        return "7-day feedback"
    }

    private static func checkInDate(_ value: String) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private var isPreviewing: Bool {
        #if DEBUG && targetEnvironment(simulator)
        previewDays != nil
        #else
        false
        #endif
    }

    private static func weekRangeText() -> String {
        let calendar = Calendar.current
        let today = Date()
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? today
        let monthDayFormatter = DateFormatter()
        monthDayFormatter.dateFormat = "MMMM d"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        if calendar.component(.month, from: start) == calendar.component(.month, from: end) {
            return "\(monthDayFormatter.string(from: start))-\(dayFormatter.string(from: end))"
        }
        return "\(monthDayFormatter.string(from: start))-\(monthDayFormatter.string(from: end))"
    }
}

struct ActivityInsightView: View {
    @EnvironmentObject private var store: AppStore

    private var insight: DailyInsight {
        store.dailyInsights.first { $0.title == store.selectedDailyInsightTitle }
        ?? DailyInsight(
            icon: "sparkles",
            title: store.selectedDailyInsightTitle,
            whatWeNoticed: "No saved detail was found for this insight.",
            whyItMayMatter: "The app should not invent details when the underlying check-in data is missing.",
            nextStep: "Return to Daily Insights and choose another card."
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Button {
                        store.showMain(tab: .progress)
                    } label: {
                        Label("Daily Insights", systemImage: "chevron.left")
                            .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColor.blue)
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppColor.text)
                        Text(Self.dayFormatter.string(from: Date()))
                            .font(.title3)
                            .foregroundStyle(AppColor.text)
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What you logged")
                                .font(.headline)
                                .foregroundStyle(AppColor.blue)
                            Text(loggedSummaryText)
                                .font(.title.bold())
                                .foregroundStyle(AppColor.text)
                            Text(loggedSummaryCaption)
                                .font(.headline)
                                .foregroundStyle(AppColor.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Today's suggestion")
                                .font(.headline)
                                .foregroundStyle(AppColor.blue)
                            InsightDetailBlock(label: "What we noticed", text: insight.whatWeNoticed)
                            InsightDetailBlock(label: "Why it may matter", text: insight.whyItMayMatter)
                            InsightDetailBlock(label: "A realistic next step", text: insight.nextStep)
                            HStack(spacing: 16) {
                                CloudyMascotView(size: 104)
                                Text("Small steps count. Choose what feels realistic today.")
                                    .font(.callout)
                                    .foregroundStyle(AppColor.text)
                            }
                        }
                    }

                    PrimaryButton(title: "View another insight") {
                        store.showMain(tab: .progress)
                    }

                    Text("Suggestions support general wellness and are not medical advice.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomTabBar()
        }
        .background(.white)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    private var loggedSummaryText: String {
        switch insight.title {
        case "Sleep":
            let trimmed = store.checkIn.sleepHours.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Not logged" : "\(trimmed) hr"
        case "Physical activity":
            return activityDurationText
        case "Movement breaks":
            let trimmed = store.checkIn.movementBreaks.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Not logged" : trimmed
        case "Food reflection", "Food journal":
            return store.checkIn.foodJournalSummary
        default:
            return "Today's check-in"
        }
    }

    private var loggedSummaryCaption: String {
        switch insight.title {
        case "Sleep":
            return "sleep duration"
        case "Physical activity":
            return store.checkIn.activityType.isEmpty ? "physical activity" : store.checkIn.activityType.lowercased()
        case "Movement breaks":
            return "movement breaks"
        case "Food reflection", "Food journal":
            return "food reflection"
        default:
            return "daily insight"
        }
    }

    private var activityDurationText: String {
        let trimmed = store.checkIn.activityDuration.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not logged" : "\(trimmed) min"
    }
}

struct SummaryTile: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppColor.blue)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppColor.text)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(AppColor.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .frame(minHeight: 76)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
    }
}

struct SuggestionRow: View {
    let insight: DailyInsight
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: insight.icon)
                    .font(.title2)
                    .foregroundStyle(AppColor.blue)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 5) {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundStyle(AppColor.text)
                    Text(insight.whatWeNoticed)
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(2)
                    Text(insight.nextStep)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AppColor.text)
                        .lineLimit(3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColor.muted)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
}

struct InsightDetailBlock: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.blue)
            Text(text)
                .font(.callout)
                .foregroundStyle(AppColor.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct FactorList: View {
    let title: String
    let icon: String
    let color: Color
    let factors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            ForEach(factors, id: \.self) { factor in
                Text("• \(factor)")
                    .font(.callout)
                    .foregroundStyle(AppColor.text)
                    .padding(.leading, 26)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrendRow: View {
    let metric: WeeklyTrendMetric
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: metric.icon)
                    .font(.title3)
                    .foregroundStyle(AppColor.blue)
                    .frame(width: 36, height: 36)
                Text(metric.title)
                    .font(.headline)
                    .foregroundStyle(AppColor.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColor.muted)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
}

enum WeeklyTrendMetric: String, Identifiable {
    case sleep
    case activity
    case movementBreaks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep:
            return "Sleep duration"
        case .activity:
            return "Physical activity"
        case .movementBreaks:
            return "Movement breaks"
        }
    }

    var icon: String {
        switch self {
        case .sleep:
            return "moon.zzz"
        case .activity:
            return "figure.walk"
        case .movementBreaks:
            return "figure.stand"
        }
    }

    var unit: String {
        switch self {
        case .sleep:
            return "hr"
        case .activity:
            return "min"
        case .movementBreaks:
            return "score"
        }
    }

    var chartColor: Color {
        switch self {
        case .sleep:
            return .indigo
        case .activity:
            return AppColor.blue
        case .movementBreaks:
            return .teal
        }
    }

    var whyItMatters: String {
        switch self {
        case .sleep:
            return "Sleep duration can affect energy regulation and may support day-to-day metabolic health."
        case .activity:
            return "Regular movement can support insulin sensitivity and make weekly patterns easier to notice."
        case .movementBreaks:
            return "Breaking up long sitting periods may support metabolic health, even when the breaks are short."
        }
    }
}

struct WeeklyTrendDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let metric: WeeklyTrendMetric
    let periodCheckIns: [StoredDailyCheckIn]

    private var trendData: TrendData {
        TrendDataBuilder.make(metric: metric, savedCheckIns: periodCheckIns)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(metric.title, systemImage: metric.icon)
                                .font(.title2.bold())
                                .foregroundStyle(AppColor.text)
                            Text(trendData.currentValueText)
                                .font(.largeTitle.bold())
                                .foregroundStyle(metric.chartColor)
                            Text(trendData.currentCaption)
                                .font(.callout)
                                .foregroundStyle(AppColor.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("\(periodCheckIns.count)-day trend")
                                    .font(.headline)
                                    .foregroundStyle(AppColor.blue)
                                Spacer()
                                Text(trendData.rangeLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColor.muted)
                            }

                            if trendData.points.count >= 2 {
                                TrendLineChart(points: trendData.points, color: metric.chartColor, unit: metric.unit)
                                    .frame(height: 220)
                                Text("This trend uses the same account's check-ins as the feedback period.")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.muted)
                            } else {
                                Text("Not enough recorded values to show this trend.")
                                    .font(.callout)
                                    .foregroundStyle(AppColor.text)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(trendData.points.count) data point\(trendData.points.count == 1 ? "" : "s") available.")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.muted)
                            }
                        }
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Why it may matter")
                                .font(.headline)
                                .foregroundStyle(AppColor.blue)
                            Text(metric.whyItMatters)
                                .font(.callout)
                                .foregroundStyle(AppColor.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Trends support reflection and are not medical advice.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
            }
            .background(.white)
            .navigationTitle(metric.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppColor.blue)
                }
            }
        }
    }
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct TrendData {
    let points: [TrendPoint]
    let currentValueText: String
    let currentCaption: String
    let rangeLabel: String
}

enum WeeklyHistorySummary {
    static func completedUniqueDayCount(_ savedCheckIns: [StoredDailyCheckIn]) -> Int {
        Set(
            savedCheckIns
                .filter(\.isCompleted)
                .map { Calendar.current.startOfDay(for: $0.checkInDate) }
        )
        .count
    }
}

enum TrendDataBuilder {
    static func make(metric: WeeklyTrendMetric, savedCheckIns: [StoredDailyCheckIn]) -> TrendData {
        let realPoints = savedCheckIns
            .filter(\.isCompleted)
            .suffix(14)
            .compactMap { stored -> TrendPoint? in
                guard let value = value(for: metric, checkIn: stored.dailyCheckIn) else { return nil }
                return TrendPoint(label: weekdayLabel(for: stored.checkInDate), value: value)
            }

        let points = Array(realPoints)
        let currentValue = points.last?.value
        let currentText = currentValue.map { formattedValue($0, metric: metric) } ?? "Not logged"
        let caption = currentValueCaption(for: metric, value: currentValue)
        let start = savedCheckIns.first?.checkInDate ?? Date()
        let end = savedCheckIns.last?.checkInDate ?? Date()

        return TrendData(
            points: points,
            currentValueText: currentText,
            currentCaption: caption,
            rangeLabel: "\(shortDate(start))- \(shortDate(end))"
        )
    }

    private static func value(for metric: WeeklyTrendMetric, checkIn: DailyCheckIn) -> Double? {
        switch metric {
        case .sleep:
            return double(checkIn.sleepHours)
        case .activity:
            return double(checkIn.activityDuration)
        case .movementBreaks:
            return movementScore(checkIn.movementBreaks)
        }
    }

    private static func formattedValue(_ value: Double, metric: WeeklyTrendMetric) -> String {
        switch metric {
        case .sleep:
            return "\(formatDecimal(value)) hr"
        case .activity:
            return "\(Int(value.rounded())) min"
        case .movementBreaks:
            return movementLabel(for: value)
        }
    }

    private static func currentValueCaption(for metric: WeeklyTrendMetric, value: Double?) -> String {
        guard value != nil else {
            return "No value was logged for today's check-in."
        }
        switch metric {
        case .sleep:
            return "Logged sleep duration from today's check-in."
        case .activity:
            return "Logged physical activity duration from today's check-in."
        case .movementBreaks:
            return "Logged movement break pattern from today's check-in."
        }
    }

    private static func movementScore(_ value: String) -> Double? {
        switch value {
        case "About once an hour or more":
            return 4
        case "A few times during the day", "A few times":
            return 3
        case "Once":
            return 2
        case "Not at all":
            return 1
        case "I did not spend much time sitting", "I did not spend much time sitting today":
            return 4
        default:
            return nil
        }
    }

    private static func movementLabel(for value: Double) -> String {
        switch Int(value.rounded()) {
        case 4:
            return "Frequent"
        case 3:
            return "A few times"
        case 2:
            return "Once"
        case 1:
            return "Not at all"
        default:
            return "Not logged"
        }
    }

    private static func double(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private static func formatDecimal(_ value: Double) -> String {
        value == floor(value) ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

struct TrendLineChart: View {
    let points: [TrendPoint]
    let color: Color
    let unit: String

    var body: some View {
        GeometryReader { proxy in
            let values = points.map(\.value)
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let padding = max((maxValue - minValue) * 0.2, unit == "score" ? 0.5 : 1)
            let lowerBound = max(0, minValue - padding)
            let upperBound = max(maxValue + padding, lowerBound + 1)
            let chartHeight = proxy.size.height - 44
            let chartWidth = proxy.size.width
            let coordinates = chartCoordinates(
                points: points,
                width: chartWidth,
                height: chartHeight,
                lowerBound: lowerBound,
                upperBound: upperBound
            )

            VStack(spacing: 8) {
                ZStack {
                    ChartGrid()

                    Path { path in
                        guard let first = coordinates.first else { return }
                        path.move(to: first)
                        for point in coordinates.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                    ForEach(Array(coordinates.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(color, lineWidth: 3))
                            .position(point)
                    }
                }
                .frame(height: chartHeight)

                HStack {
                    ForEach(points) { point in
                        Text(point.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColor.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 28)
            }
        }
    }

    private func chartCoordinates(points: [TrendPoint], width: CGFloat, height: CGFloat, lowerBound: Double, upperBound: Double) -> [CGPoint] {
        guard points.count > 1 else {
            return points.map { _ in CGPoint(x: width / 2, y: height / 2) }
        }

        let step = width / CGFloat(points.count - 1)
        return points.enumerated().map { index, point in
            let progress = (point.value - lowerBound) / (upperBound - lowerBound)
            let y = height - (height * CGFloat(progress))
            return CGPoint(x: CGFloat(index) * step, y: min(max(y, 6), height - 6))
        }
    }
}

struct ChartGrid: View {
    var body: some View {
        VStack {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(AppColor.line)
                    .frame(height: 1)
                if index < 3 {
                    Spacer()
                }
            }
        }
    }
}
