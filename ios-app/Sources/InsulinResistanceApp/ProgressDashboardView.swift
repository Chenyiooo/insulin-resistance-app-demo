import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedSegment = 0

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

                    PredictionStatusBanner(mode: store.riskPredictionMode)

                    if selectedSegment == 0 {
                        DailyInsightsView()
                    } else {
                        WeeklyRiskView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.white)
    }
}

struct PredictionStatusBanner: View {
    let mode: RiskPredictionMode

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
                        if insight.title == "Physical activity" {
                            store.screen = .activityInsight
                        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Week of \(Self.weekRangeText())")
                .font(.headline)
                .foregroundStyle(AppColor.text)

            SectionCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.weeklyRisk.band)
                                .font(.title2.bold())
                                .foregroundStyle(AppColor.blue)
                            Text("\(store.weeklyRisk.score)% estimated risk")
                                .font(.headline)
                                .foregroundStyle(AppColor.text)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(Color.blue.opacity(0.15), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: CGFloat(store.weeklyRisk.score) / 100)
                                .stroke(AppColor.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(store.weeklyRisk.score)%")
                                .font(.headline)
                                .foregroundStyle(AppColor.blue)
                        }
                        .frame(width: 72, height: 72)
                    }

                    Slider(value: .constant(Double(store.weeklyRisk.score)), in: 0...100)
                        .tint(AppColor.blue)
                        .disabled(true)

                    Text(riskComparisonText)
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
                    factors: store.weeklyRisk.increasing
                )
                Divider().padding(.vertical, 8)
                FactorList(
                    title: "Decreasing estimate",
                    icon: "arrow.down.circle",
                    color: .green,
                    factors: store.weeklyRisk.decreasing
                )
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
        .sheet(item: $selectedTrend) { metric in
            WeeklyTrendDetailView(metric: metric)
                .environmentObject(store)
        }
    }

    private var riskComparisonText: String {
        let cutoff = 65
        if store.weeklyRisk.score >= cutoff {
            return "Your estimate is \(store.weeklyRisk.score - cutoff) percentage points above the high-risk cutoff."
        }
        return "Your estimate is \(cutoff - store.weeklyRisk.score) percentage points below the high-risk cutoff."
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
        store.dailyInsights.first { $0.title == "Physical activity" }
        ?? DailyInsight(
            icon: "figure.walk",
            title: "Physical activity",
            whatWeNoticed: "No physical activity answer was logged today.",
            whyItMayMatter: "Without activity information, the app should not infer whether today was active or inactive.",
            nextStep: "Try answering the activity question tomorrow, even if the answer is no."
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
                        Text("Physical Activity")
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
                            Text(activityDurationText)
                                .font(.title.bold())
                                .foregroundStyle(AppColor.text)
                            Text("moderate activity")
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
    @Query(sort: \StoredDailyCheckIn.checkInDate) private var savedCheckIns: [StoredDailyCheckIn]

    let metric: WeeklyTrendMetric

    private var trendData: TrendData {
        TrendDataBuilder.make(metric: metric, savedCheckIns: savedCheckIns, currentCheckIn: store.checkIn)
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
                                Text("Weekly trend")
                                    .font(.headline)
                                    .foregroundStyle(AppColor.blue)
                                Spacer()
                                Text(trendData.rangeLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColor.muted)
                            }

                            TrendLineChart(points: trendData.points, color: metric.chartColor, unit: metric.unit)
                                .frame(height: 220)

                            if trendData.isPreview {
                                Text("Preview trend shown until more saved check-ins are available.")
                                    .font(.caption)
                                    .foregroundStyle(AppColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("This trend uses saved daily check-ins on this device.")
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
    let isPreview: Bool
}

enum TrendDataBuilder {
    static func make(metric: WeeklyTrendMetric, savedCheckIns: [StoredDailyCheckIn], currentCheckIn: DailyCheckIn) -> TrendData {
        let calendar = Calendar.current
        let realPoints = savedCheckIns
            .filter(\.isCompleted)
            .suffix(7)
            .compactMap { stored -> TrendPoint? in
                guard let value = value(for: metric, checkIn: stored.dailyCheckIn) else { return nil }
                return TrendPoint(label: weekdayLabel(for: stored.checkInDate), value: value)
            }

        let currentValue = value(for: metric, checkIn: currentCheckIn)
        let points: [TrendPoint]
        let isPreview: Bool

        if realPoints.count >= 2 {
            points = Array(realPoints)
            isPreview = false
        } else {
            points = previewPoints(for: metric, currentValue: currentValue)
            isPreview = true
        }

        let currentText = currentValue.map { formattedValue($0, metric: metric) } ?? "Not logged"
        let caption = currentValueCaption(for: metric, value: currentValue)
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        return TrendData(
            points: points,
            currentValueText: currentText,
            currentCaption: caption,
            rangeLabel: "\(shortDate(start))- \(shortDate(today))",
            isPreview: isPreview
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

    private static func previewPoints(for metric: WeeklyTrendMetric, currentValue: Double?) -> [TrendPoint] {
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Today"]
        let fallback: [Double]
        switch metric {
        case .sleep:
            let value = currentValue ?? 6.5
            fallback = [value - 0.6, value - 0.2, value + 0.1, value - 0.4, value + 0.3, value, value + 0.2]
        case .activity:
            let value = currentValue ?? 20
            fallback = [max(0, value - 15), value, max(0, value - 8), value + 10, value + 5, max(0, value - 5), value + 12]
        case .movementBreaks:
            let value = currentValue ?? 3
            fallback = [max(1, value - 1), value, max(1, value - 0.5), min(4, value + 1), value, min(4, value + 0.5), value]
        }
        return zip(labels, fallback).map { TrendPoint(label: $0.0, value: max(0, $0.1)) }
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
