import SwiftUI

struct ProgressDashboardView: View {
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

struct DailyInsightsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chevron.left")
                    .foregroundStyle(AppColor.blue)
                Spacer()
                Text("Today · August 7")
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
                SummaryTile(icon: "moon.zzz", title: "Sleep", value: "\(store.checkIn.sleepHours) hr")
                SummaryTile(icon: "figure.walk", title: "Moderate activity", value: "\(store.checkIn.activityDuration) min")
                SummaryTile(icon: "figure.stand", title: "Movement breaks", value: store.checkIn.movementBreaks)
                SummaryTile(icon: "fork.knife", title: "Food journal", value: store.checkIn.foodJournal)
            }

            Text("Suggestions for today")
                .font(.headline)

            VStack(spacing: 0) {
                SuggestionRow(icon: "figure.walk", title: "Physical activity", detail: "A 10-minute walk after your next meal could add a little more movement.") {
                    store.screen = .activityInsight
                }
                Divider()
                SuggestionRow(icon: "figure.stand", title: "Movement breaks", detail: "Try standing or walking for 2-3 minutes during your next hour of sitting.") {}
                Divider()
                SuggestionRow(icon: "fork.knife", title: "Food journal", detail: "Review today's meals and notice anything that stood out.") {}
                Divider()
                SuggestionRow(icon: "moon.zzz", title: "Sleep", detail: "Try beginning your bedtime routine 30 minutes earlier tonight.") {}
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))

            Text("Suggestions support general wellness and are not medical advice.")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
        }
    }
}

struct WeeklyRiskView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Week of August 3-9")
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

                    Text("Your estimate is 14 percentage points above the high-risk cutoff.")
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
                TrendRow(icon: "scale.3d", title: "Weight & waist")
                Divider()
                TrendRow(icon: "heart.text.square", title: "Blood pressure")
                Divider()
                TrendRow(icon: "moon.zzz", title: "Sleep")
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
        }
    }
}

struct ActivityInsightView: View {
    @EnvironmentObject private var store: AppStore

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
                        Text("August 7")
                            .font(.title3)
                            .foregroundStyle(AppColor.text)
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What you logged")
                                .font(.headline)
                                .foregroundStyle(AppColor.blue)
                            Text("\(store.checkIn.activityDuration) min")
                                .font(.title.bold())
                                .foregroundStyle(AppColor.text)
                            Text("moderate activity")
                                .font(.headline)
                                .foregroundStyle(AppColor.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 22) {
                            Text("Today's suggestion")
                                .font(.headline)
                                .foregroundStyle(AppColor.blue)
                            Text("Try taking a 10-minute walk after your next meal to add a little more movement to your day.")
                                .font(.title3)
                                .foregroundStyle(AppColor.text)
                                .lineSpacing(4)
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
            }
            Spacer()
        }
        .padding(12)
        .frame(height: 76)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
    }
}

struct SuggestionRow: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(AppColor.blue)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppColor.text)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(AppColor.text)
                        .lineLimit(2)
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
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppColor.blue)
                .frame(width: 36, height: 36)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.text)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppColor.muted)
        }
        .padding(14)
    }
}
