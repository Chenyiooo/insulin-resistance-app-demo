import SwiftUI
import SwiftData

private enum AIQuestionStep {
    case sleep
    case activity
    case activityDetails
    case movement
    case food
    case reflection

    var title: String {
        switch self {
        case .sleep:
            return "Sleep"
        case .activity:
            return "Physical activity"
        case .activityDetails:
            return "Activity details"
        case .movement:
            return "Movement breaks"
        case .food:
            return "Food journal"
        case .reflection:
            return "Reflection"
        }
    }

    var prompt: String {
        switch self {
        case .sleep:
            return "About how many hours did you sleep last night?"
        case .activity:
            return "Were you physically active today?"
        case .activityDetails:
            return "Tell me what kind of activity you did and about how long it lasted. You can skip details if you want."
        case .movement:
            return "During sitting periods today, how often did you get up and move for at least 2-3 minutes?"
        case .food:
            return "Would you like to add a food journal for today? This is optional."
        case .reflection:
            return "Anything else you noticed about sleep, movement, food, energy, stress, or your routine today? This is optional."
        }
    }

    var progressText: String {
        switch self {
        case .sleep:
            return "1 of 5"
        case .activity:
            return "2 of 5"
        case .activityDetails:
            return "2 of 5"
        case .movement:
            return "3 of 5"
        case .food:
            return "4 of 5"
        case .reflection:
            return "5 of 5"
        }
    }

    var progressValue: Double {
        switch self {
        case .sleep:
            return 0.2
        case .activity, .activityDetails:
            return 0.4
        case .movement:
            return 0.6
        case .food:
            return 0.8
        case .reflection:
            return 1.0
        }
    }
}

struct AICheckInView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @State private var typedAnswer = ""
    @State private var selectedOption: String?
    @State private var step: AIQuestionStep = .sleep
    @State private var isShowingHealthImport = false
    @State private var missingItems: [MissingDataItem] = []
    @State private var isShowingMissingDataWarning = false

    var body: some View {
        VStack(spacing: 0) {
            header
            progressHeader
            topActions

            ScrollView {
                VStack(spacing: 24) {
                    HStack(alignment: .top, spacing: 16) {
                        CloudyMascotView(size: 104)
                        Text(cloudyMessage)
                            .font(.title3)
                            .foregroundStyle(AppColor.text)
                            .lineSpacing(6)
                            .padding(22)
                            .background(AppColor.softViolet)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.top, 34)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(step.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColor.blue)
                        Text(step.prompt)
                            .font(.title2.bold())
                            .foregroundStyle(AppColor.text)
                            .lineSpacing(8)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.softViolet)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if !optionButtons.isEmpty {
                        Text(optionHint)
                            .font(.callout)
                            .foregroundStyle(AppColor.muted)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(optionButtons, id: \.self) { option in
                                Button {
                                    choose(option)
                                } label: {
                                    Text(option)
                                        .font(.headline)
                                        .foregroundStyle(AppColor.text)
                                        .multilineTextAlignment(.center)
                                        .minimumScaleFactor(0.85)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 76)
                                        .background(selectedOption == option ? Color.blue.opacity(0.12) : .white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.45)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 14) {
                TextField(textPlaceholder, text: $typedAnswer)
                    .textFieldStyle(AppTextFieldStyle())
                    .overlay(alignment: .trailing) {
                        Image(systemName: "mic")
                            .font(.title2)
                            .foregroundStyle(AppColor.muted)
                            .padding(.trailing, 16)
                    }
                Button {
                    submitTypedAnswer()
                } label: {
                    Image(systemName: step == .reflection ? "checkmark" : "paperplane.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(AppColor.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .overlay(alignment: .top) {
                Rectangle().fill(AppColor.line).frame(height: 1)
            }

            BottomTabBar()
        }
        .background(.white)
        .sheet(isPresented: $isShowingHealthImport) {
            AppleHealthImportSheet { result in
                store.applyHealthImport(result)
                store.saveCheckIn(in: modelContext)
                isShowingHealthImport = false
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Required answer missing", isPresented: $isShowingMissingDataWarning) {
            Button("Review", role: .cancel) {}
        } message: {
            Text(missingDataMessage)
        }
    }

    private var cloudyMessage: String {
        switch step {
        case .sleep:
            return "Hi \(store.profile.name)! I’ll ask each check-in question one at a time."
        case .activityDetails:
            return "Thanks. If you know the activity type or minutes, add them here. If not, skip is fine."
        case .food, .reflection:
            return "This part is optional. I won’t guess if you leave it blank."
        default:
            return "Got it. Let’s keep going."
        }
    }

    private var optionHint: String {
        step == .food || step == .reflection
            ? "Choose an option or type your own answer."
            : "Choose an option or tell me in your own words."
    }

    private var textPlaceholder: String {
        switch step {
        case .sleep:
            return "e.g., 6.5 hours"
        case .activity:
            return "e.g., yes or no"
        case .activityDetails:
            return "e.g., brisk walking for 20 minutes"
        case .movement:
            return "Type your answer..."
        case .food:
            return "e.g., chicken rice and an apple"
        case .reflection:
            return "Optional reflection..."
        }
    }

    private var optionButtons: [String] {
        switch step {
        case .sleep:
            return ["5 hr", "6 hr", "7 hr", "8 hr"]
        case .activity:
            return ["Yes", "No"]
        case .activityDetails:
            return ["Brisk walking 20 min", "Strength training 20 min", "Skip details"]
        case .movement:
            return [
                "About once an hour or more",
                "A few times during the day",
                "Once",
                "Not at all",
                "I did not spend much time sitting today",
            ]
        case .food:
            return ["Skip food journal", "Add food note"]
        case .reflection:
            return ["Finish check-in", "Skip reflection"]
        }
    }

    private var missingDataMessage: String {
        if missingItems.isEmpty { return "" }
        let labels = missingItems.map { "\($0.label): \($0.code)" }.joined(separator: "\n")
        return "Please answer before continuing.\n\n\(labels)"
    }

    private func choose(_ option: String) {
        selectedOption = option
        switch step {
        case .sleep:
            store.checkIn.sleepHours = option.replacingOccurrences(of: " hr", with: "")
            move(to: .activity)
        case .activity:
            if option == "Yes" {
                store.checkIn.activeToday = true
                move(to: .activityDetails)
            } else {
                store.checkIn.activeToday = false
                store.checkIn.activityType = ""
                store.checkIn.activityDuration = ""
                move(to: .movement)
            }
        case .activityDetails:
            if option != "Skip details" {
                applyActivityDetails(option)
            }
            move(to: .movement)
        case .movement:
            store.checkIn.movementBreaks = option
            move(to: .food)
        case .food:
            if option == "Skip food journal" {
                store.checkIn.foodJournal = "Skipped"
            }
            move(to: .reflection)
        case .reflection:
            completeWithValidation()
        }
    }

    private func submitTypedAnswer() {
        let answer = typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch step {
        case .sleep:
            guard let hours = firstNumber(in: answer) else {
                showMissing(field: "sleep_hours", label: "Sleep duration")
                return
            }
            store.checkIn.sleepHours = formatNumber(hours)
            move(to: .activity)
        case .activity:
            let lowercased = answer.lowercased()
            if lowercased.contains("yes") || lowercased.contains("active") || lowercased.contains("walk") || lowercased.contains("run") {
                store.checkIn.activeToday = true
                if lowercased.contains("walk") || lowercased.contains("run") || lowercased.contains("strength") {
                    applyActivityDetails(answer)
                }
                move(to: .activityDetails)
            } else if lowercased.contains("no") || lowercased.contains("not") {
                store.checkIn.activeToday = false
                move(to: .movement)
            } else {
                showMissing(field: "physical_activity_today", label: "Physical activity")
            }
        case .activityDetails:
            if !answer.isEmpty {
                applyActivityDetails(answer)
            }
            move(to: .movement)
        case .movement:
            guard !answer.isEmpty else {
                showMissing(field: "movement_breaks", label: "Movement breaks")
                return
            }
            store.checkIn.movementBreaks = normalizedMovementAnswer(answer)
            move(to: .food)
        case .food:
            if !answer.isEmpty {
                store.checkIn.foodJournal = "Added"
                store.checkIn.foodJournalDescription = answer
                store.estimateFoodNutrition(text: answer, imageBase64: [])
            }
            move(to: .reflection)
        case .reflection:
            if !answer.isEmpty {
                store.checkIn.dailyReflection = answer
            }
            completeWithValidation()
        }
    }

    private func move(to nextStep: AIQuestionStep) {
        typedAnswer = ""
        selectedOption = nil
        step = nextStep
        store.saveCheckIn(in: modelContext)
    }

    private func showMissing(field: String, label: String) {
        missingItems = [
            MissingDataItem(field: field, label: label, code: MissingDataCode.missing)
        ]
        isShowingMissingDataWarning = true
    }

    private func completeWithValidation() {
        var items: [MissingDataItem] = []
        if store.checkIn.sleepHours.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(MissingDataItem(field: "sleep_hours", label: "Sleep duration", code: MissingDataCode.missing))
        }
        if store.checkIn.activeToday == nil {
            items.append(MissingDataItem(field: "physical_activity_today", label: "Physical activity", code: MissingDataCode.missing))
        }
        if store.checkIn.movementBreaks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(MissingDataItem(field: "movement_breaks", label: "Movement breaks", code: MissingDataCode.missing))
        }
        guard items.isEmpty else {
            missingItems = items
            isShowingMissingDataWarning = true
            return
        }
        store.checkIn.isCompleted = true
        store.saveCheckIn(in: modelContext)
        store.screen = .completion
    }

    private func applyActivityDetails(_ text: String) {
        let lowercased = text.lowercased()
        if lowercased.contains("strength") || lowercased.contains("weight") {
            store.checkIn.activityType = "Strength training"
        } else if lowercased.contains("run") {
            store.checkIn.activityType = "Running"
        } else if lowercased.contains("cycle") || lowercased.contains("bike") {
            store.checkIn.activityType = "Cycling"
        } else if lowercased.contains("swim") {
            store.checkIn.activityType = "Swimming"
        } else if lowercased.contains("walk") {
            store.checkIn.activityType = "Brisk walking"
        } else if store.checkIn.activityType.isEmpty {
            store.checkIn.activityType = text
        }

        if let minutes = firstNumber(in: text) {
            store.checkIn.activityDuration = "\(Int(minutes.rounded()))"
        }
    }

    private func normalizedMovementAnswer(_ answer: String) -> String {
        let lowercased = answer.lowercased()
        if lowercased.contains("hour") || lowercased.contains("hourly") {
            return "About once an hour or more"
        }
        if lowercased.contains("few") || lowercased.contains("several") {
            return "A few times during the day"
        }
        if lowercased.contains("once") || lowercased == "1" {
            return "Once"
        }
        if lowercased.contains("not") || lowercased.contains("none") || lowercased == "0" {
            return "Not at all"
        }
        if lowercased.contains("did not sit") || lowercased.contains("not much sitting") {
            return "I did not spend much time sitting today"
        }
        return answer
    }

    private func firstNumber(in text: String) -> Double? {
        let pattern = #"(\d+(\.\d+)?)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Double(text[range])
    }

    private func formatNumber(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private var topActions: some View {
        VStack(spacing: 10) {
            AppleHealthRow {
                isShowingHealthImport = true
            }

            Button {
                store.screen = .manualCheckIn
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.title3)
                        .foregroundStyle(AppColor.blue)
                        .frame(width: 42, height: 42)
                        .background(Color.blue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Switch to manual input")
                            .font(.headline)
                            .foregroundStyle(AppColor.text)
                        Text("Use the guided form instead")
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColor.text)
                }
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.white)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.line).frame(height: 1)
        }
    }

    private var header: some View {
        HStack {
            Button {
                store.screen = .checkInEntry
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title.weight(.regular))
                    .foregroundStyle(AppColor.text)
            }
            Spacer()
            Text("Daily Check-in")
                .font(.title.bold())
                .foregroundStyle(AppColor.text)
            Spacer()
            Button("Exit") {
                store.showMain(tab: .home)
            }
            .font(.headline)
            .foregroundStyle(AppColor.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.blue))
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.line).frame(height: 1)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's check-in")
                Spacer()
                Text(step.progressText)
            }
            .font(.title3)
            .foregroundStyle(AppColor.text)
            ProgressView(value: step.progressValue)
                .tint(AppColor.blue)
        }
        .padding(24)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.line).frame(height: 1)
        }
    }
}
