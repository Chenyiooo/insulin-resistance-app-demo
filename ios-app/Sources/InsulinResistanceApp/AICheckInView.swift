import SwiftUI
import SwiftData
import PhotosUI
import UIKit

private enum AIQuestionStep {
    case weight
    case waist
    case sleep
    case activity
    case activityDetails
    case movement
    case food
    case reflection

    var title: String {
        switch self {
        case .weight:
            return "Weight"
        case .waist:
            return "Waist circumference"
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
        case .weight:
            return "What is your current weight?"
        case .waist:
            return "What is your waist circumference?"
        case .sleep:
            return "About how many hours did you sleep last night?"
        case .activity:
            return "Were you physically active today?"
        case .activityDetails:
            return "Tell me what kind of activity you did and about how long it lasted."
        case .movement:
            return "During sitting periods today, how often did you get up and move for at least 2-3 minutes?"
        case .food:
            return "Would you like to add a food journal for today? This is optional."
        case .reflection:
            return "What did you notice about sleep, movement, food, energy, stress, or your routine today?"
        }
    }

    var progressText: String {
        switch self {
        case .weight:
            return "1 of 7"
        case .waist:
            return "2 of 7"
        case .sleep:
            return "3 of 7"
        case .activity:
            return "4 of 7"
        case .activityDetails:
            return "4 of 7"
        case .movement:
            return "5 of 7"
        case .food:
            return "6 of 7"
        case .reflection:
            return "7 of 7"
        }
    }

    var progressValue: Double {
        switch self {
        case .weight:
            return 1.0 / 7.0
        case .waist:
            return 2.0 / 7.0
        case .sleep:
            return 3.0 / 7.0
        case .activity, .activityDetails:
            return 4.0 / 7.0
        case .movement:
            return 5.0 / 7.0
        case .food:
            return 6.0 / 7.0
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
    @State private var step: AIQuestionStep = .weight
    @State private var isShowingHealthImport = false
    @State private var missingItems: [MissingDataItem] = []
    @State private var isShowingMissingDataWarning = false
    @State private var selectedFoodPhotos: [PhotosPickerItem] = []
    @State private var foodPhotoBase64: [String] = []
    @State private var isFoodDescriptionVisible = false
    private var greetingName: String {
        let trimmedName = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "there" : trimmedName
    }

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

                    if step == .food {
                        foodJournalPanel
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
        case .weight:
            return "Hi \(greetingName)! I’ll ask each required check-in question one at a time."
        case .waist:
            return "Thanks. This helps keep today’s check-in complete before feedback is generated."
        case .sleep:
            return "Got it. Now let’s check in on last night’s sleep."
        case .activityDetails:
            return "Thanks. Since you were active today, I need the activity type and duration too."
        case .food:
            return "This part is optional. I won’t guess if you leave it blank."
        case .reflection:
            return "One last required question. A short sentence is enough."
        default:
            return "Got it. Let’s keep going."
        }
    }

    private var optionHint: String {
        step == .food || step == .reflection || step == .weight || step == .waist
            ? "Choose an option or type your own answer."
            : "Choose an option or tell me in your own words."
    }

    private var textPlaceholder: String {
        switch step {
        case .weight:
            return "e.g., 165 lb or 75 kg"
        case .waist:
            return "e.g., 34 in or 86 cm"
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
            return "e.g., I felt more tired than usual..."
        }
    }

    private var optionButtons: [String] {
        switch step {
        case .weight, .waist:
            return []
        case .sleep:
            return ["5 hr", "6 hr", "7 hr", "8 hr"]
        case .activity:
            return ["Yes", "No"]
        case .activityDetails:
            return ["Brisk walking 20 min", "Strength training 20 min", "Cycling 20 min", "Yoga 20 min"]
        case .movement:
            return [
                "About once an hour or more",
                "A few times during the day",
                "Once",
                "Not at all",
                "I did not spend much time sitting today",
            ]
        case .food:
            return []
        case .reflection:
            return []
        }
    }

    private var missingDataMessage: String {
        if missingItems.isEmpty { return "" }
        let labels = missingItems.map { "\($0.label): \($0.code)" }.joined(separator: "\n")
        return "Please answer before continuing.\n\n\(labels)"
    }

    private var foodJournalPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add food journal")
                .font(.headline)
                .foregroundStyle(AppColor.text)
            Text("Upload photos, describe what you ate and drank, or skip this optional question.")
                .font(.callout)
                .foregroundStyle(AppColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedFoodPhotos, maxSelectionCount: 8, matching: .images) {
                    FoodJournalActionButton(
                        icon: "photo.on.rectangle",
                        title: selectedFoodPhotos.isEmpty ? "Upload Photos" : "\(selectedFoodPhotos.count) Photo\(selectedFoodPhotos.count == 1 ? "" : "s") Selected"
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: selectedFoodPhotos) { _, newValue in
                    store.checkIn.foodPhotoCount = newValue.count
                    updateFoodJournalStatus()
                    Task {
                        foodPhotoBase64 = await loadJPEGBase64(from: newValue)
                        store.estimateFoodNutrition(
                            text: store.checkIn.foodJournalDescription,
                            imageBase64: foodPhotoBase64
                        )
                    }
                }

                Button {
                    isFoodDescriptionVisible = true
                } label: {
                    FoodJournalActionButton(
                        icon: "square.and.pencil",
                        title: "Describe Food"
                    )
                }
                .buttonStyle(.plain)
            }

            if isFoodDescriptionVisible {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Food description")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                    TextEditor(text: $store.checkIn.foodJournalDescription)
                        .frame(minHeight: 92)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
                        .onChange(of: store.checkIn.foodJournalDescription) { _, _ in
                            updateFoodJournalStatus()
                        }
                    Button {
                        estimateFoodAndContinue()
                    } label: {
                        Label("Estimate nutrition and continue", systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppColor.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isEstimatingNutrition)
                }
            }

            if store.checkIn.foodJournalSummary != "Not added" {
                HStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .foregroundStyle(AppColor.blue)
                    Text(store.checkIn.foodJournalSummary)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.sky)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if store.isEstimatingNutrition {
                Label("Estimating nutrition from food input...", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            } else if !store.nutritionEstimateMessage.isEmpty {
                Label(store.nutritionEstimateMessage, systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }

            Label("Nutrition values are estimates, not medical or dietary advice.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(AppColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                OutlineButton(title: "Skip food journal") {
                    skipFoodJournal()
                }
                PrimaryButton(title: "Continue") {
                    continueFromFoodJournal()
                }
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
    }

    private func choose(_ option: String) {
        selectedOption = option
        switch step {
        case .weight, .waist:
            return
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
            applyActivityDetails(option)
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
        case .weight:
            guard let weight = firstNumber(in: answer) else {
                showMissing(field: "weight", label: "Weight")
                return
            }
            store.checkIn.weight = formatNumber(weight)
            store.checkIn.weightUnit = normalizedWeightUnit(from: answer)
            move(to: .waist)
        case .waist:
            guard let waist = firstNumber(in: answer) else {
                showMissing(field: "waist_circumference", label: "Waist circumference")
                return
            }
            store.checkIn.waist = formatNumber(waist)
            store.checkIn.waistUnit = normalizedWaistUnit(from: answer)
            move(to: .sleep)
        case .sleep:
            guard let hours = firstNumber(in: answer) else {
                showMissing(field: "sleep_hours", label: "Sleep duration")
                return
            }
            store.checkIn.sleepHours = formatNumber(hours)
            move(to: .activity)
        case .activity:
            let lowercased = answer.lowercased()
            if lowercased.contains("yes")
                || lowercased.contains("active")
                || lowercased.contains("walk")
                || lowercased.contains("run")
                || lowercased.contains("cycle")
                || lowercased.contains("bike")
                || lowercased.contains("swim")
                || lowercased.contains("yoga")
                || lowercased.contains("strength") {
                store.checkIn.activeToday = true
                applyActivityDetails(answer)
                move(to: hasRequiredActivityDetails ? .movement : .activityDetails)
            } else if lowercased.contains("no") || lowercased.contains("not") {
                store.checkIn.activeToday = false
                move(to: .movement)
            } else {
                showMissing(field: "physical_activity_today", label: "Physical activity")
            }
        case .activityDetails:
            guard !answer.isEmpty else {
                showMissing(field: "activity_details", label: "Activity type and duration")
                return
            }
            applyActivityDetails(answer)
            guard hasRequiredActivityDetails else {
                showMissing(field: "activity_details", label: "Activity type and duration")
                return
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
                store.estimateFoodNutrition(text: answer, imageBase64: foodPhotoBase64)
            }
            continueFromFoodJournal()
        case .reflection:
            guard !answer.isEmpty else {
                showMissing(field: "daily_reflection", label: "Daily reflection")
                return
            }
            store.checkIn.dailyReflection = answer
            completeWithValidation()
        }
    }

    private func updateFoodJournalStatus() {
        let hasDescription = !store.checkIn.foodJournalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPhotos = store.checkIn.foodPhotoCount > 0
        let hasNutrition = [
            store.checkIn.foodCalories,
            store.checkIn.foodCarbohydrates,
            store.checkIn.foodProtein,
            store.checkIn.foodFat,
        ].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if hasDescription || hasPhotos || hasNutrition {
            store.checkIn.foodJournal = "Added"
        } else if store.checkIn.foodJournal != "Skipped" {
            store.checkIn.foodJournal = ""
        }
    }

    private func estimateFoodAndContinue() {
        let description = store.checkIn.foodJournalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty || !foodPhotoBase64.isEmpty {
            store.checkIn.foodJournal = "Added"
            store.estimateFoodNutrition(text: description, imageBase64: foodPhotoBase64)
        }
        move(to: .reflection)
    }

    private func continueFromFoodJournal() {
        let description = store.checkIn.foodJournalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty || store.checkIn.foodPhotoCount > 0 {
            store.checkIn.foodJournal = "Added"
            if !description.isEmpty || !foodPhotoBase64.isEmpty {
                store.estimateFoodNutrition(text: description, imageBase64: foodPhotoBase64)
            }
        } else if store.checkIn.foodJournal != "Skipped" {
            store.checkIn.foodJournal = ""
        }
        move(to: .reflection)
    }

    private func skipFoodJournal() {
        selectedFoodPhotos = []
        foodPhotoBase64 = []
        isFoodDescriptionVisible = false
        store.checkIn.foodPhotoCount = 0
        store.checkIn.foodJournalDescription = ""
        store.checkIn.foodCalories = ""
        store.checkIn.foodCarbohydrates = ""
        store.checkIn.foodProtein = ""
        store.checkIn.foodFat = ""
        store.checkIn.foodNutritionSource = ""
        store.checkIn.foodNutritionConfidence = ""
        store.checkIn.foodNutritionExplanation = ""
        store.checkIn.foodNutritionMatchedFoods = ""
        store.nutritionEstimateMessage = ""
        store.checkIn.foodJournal = "Skipped"
        move(to: .reflection)
    }

    private func loadJPEGBase64(from items: [PhotosPickerItem]) async -> [String] {
        var encodedImages: [String] = []
        for item in items.prefix(4) {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                continue
            }
            let jpegData: Data
            if let image = UIImage(data: data), let compressed = image.jpegData(compressionQuality: 0.72) {
                jpegData = compressed
            } else {
                jpegData = data
            }
            encodedImages.append(jpegData.base64EncodedString())
        }
        return encodedImages
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
        let items = store.checkInMissingDataItems()
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
        } else if lowercased.contains("yoga") || lowercased.contains("stretch") {
            store.checkIn.activityType = "Yoga or stretching"
        } else if lowercased.contains("sport") {
            store.checkIn.activityType = "Sports"
        } else if store.checkIn.activityType.isEmpty {
            store.checkIn.activityType = text
        }

        if let minutes = firstNumber(in: text) {
            store.checkIn.activityDuration = "\(Int(minutes.rounded()))"
        }
    }

    private var hasRequiredActivityDetails: Bool {
        !store.checkIn.activityType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.checkIn.activityDuration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func normalizedWeightUnit(from text: String) -> String {
        text.lowercased().contains("kg") ? "kg" : "lb"
    }

    private func normalizedWaistUnit(from text: String) -> String {
        let lowercased = text.lowercased()
        return lowercased.contains("cm") ? "cm" : "in"
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
