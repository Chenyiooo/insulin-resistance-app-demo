import SwiftUI

struct AppleHealthImportSheet: View {
    @StateObject private var healthKitService = HealthKitService()
    let useData: (HealthImportResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Capsule()
                .fill(AppColor.line)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("Apple Health", systemImage: "heart.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.red)
                Text("Review imported data")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColor.text)
                Text("The app will request Health permission and import available sleep, workouts, weight, and blood pressure. Review the values before using them.")
                    .font(.callout)
                    .foregroundStyle(AppColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content

            Spacer()
        }
        .padding(22)
        .background(Color(red: 0.98, green: 0.99, blue: 1.0))
        .task {
            if case .idle = healthKitService.state {
                await healthKitService.requestAndFetchToday()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch healthKitService.state {
        case .idle, .loading:
            VStack(spacing: 14) {
                ProgressView()
                    .tint(AppColor.blue)
                Text("Requesting Health permission and reading today's data...")
                    .font(.callout)
                    .foregroundStyle(AppColor.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(26)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))

        case .loaded(let result):
            VStack(alignment: .leading, spacing: 18) {
                if result.hasAnyData {
                    importedRows(result)
                    PrimaryButton(title: "Use these data") {
                        useData(result)
                    }
                } else {
                    statusMessage(
                        title: "No Health data found for today",
                        body: "You can still enter today's check-in manually. If you expected data here, check Apple Health permissions and whether your device has today's samples."
                    )
                    Button("Try Again") {
                        Task { await healthKitService.requestAndFetchToday() }
                    }
                    .font(.headline)
                    .foregroundStyle(AppColor.blue)
                }
            }

        case .unavailable(let message):
            statusMessage(title: "Apple Health unavailable", body: message)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 14) {
                statusMessage(title: "Could not import Health data", body: message)
                Button("Try Again") {
                    Task { await healthKitService.requestAndFetchToday() }
                }
                .font(.headline)
                .foregroundStyle(AppColor.blue)
            }
        }
    }

    private func importedRows(_ result: HealthImportResult) -> some View {
        VStack(spacing: 0) {
            ImportedHealthRow(
                icon: "moon.zzz",
                title: "Last night's sleep",
                value: result.sleepHours.map { String(format: "%.1f hr", $0) } ?? "No data"
            )
            Divider()
            ImportedHealthRow(
                icon: "figure.walk",
                title: result.activityName ?? "Today's activity",
                value: result.activityMinutes.map { "\($0) min" } ?? "No data"
            )
            if !result.activities.isEmpty {
                ForEach(result.activities) { activity in
                    ImportedHealthSubrow(title: activity.name, value: "\(activity.minutes) min")
                }
            }
            Divider()
            ImportedHealthRow(
                icon: "heart.text.square",
                title: "Recent blood pressure",
                value: bloodPressureText(result),
                detail: result.bloodPressureDate.map { "Measured \(Self.shortDate($0))" }
            )
            Divider()
            ImportedHealthRow(
                icon: "scalemass",
                title: "Recent weight",
                value: result.weightPounds.map { String(format: "%.0f lb", $0) } ?? "No data",
                detail: result.weightDate.map { "Measured \(Self.shortDate($0))" }
            )
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
    }

    private func statusMessage(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.text)
            Text(body)
                .font(.callout)
                .foregroundStyle(AppColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
    }

    private func bloodPressureText(_ result: HealthImportResult) -> String {
        guard let systolic = result.systolic, let diastolic = result.diastolic else {
            return "No data"
        }
        return "\(Int(systolic.rounded()))/\(Int(diastolic.rounded()))"
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct ImportedHealthRow: View {
    let icon: String
    let title: String
    let value: String
    var detail: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppColor.blue)
                .frame(width: 38, height: 38)
                .background(Color.blue.opacity(0.08))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColor.text)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(AppColor.muted)
        }
        .padding(14)
    }
}

struct ImportedHealthSubrow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColor.muted)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.text)
        }
        .padding(.leading, 66)
        .padding(.trailing, 14)
        .padding(.bottom, 8)
    }
}
