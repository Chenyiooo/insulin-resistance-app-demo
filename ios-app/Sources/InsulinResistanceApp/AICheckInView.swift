import SwiftUI
import SwiftData
import PhotosUI
import UIKit

private enum AIQuestionStep: Hashable {
    case weight
    case waist
    case bloodPressureChoice
    case bloodPressureSystolic
    case bloodPressureDiastolic
    case bloodPressureDate
    case sleep
    case activity
    case activityType
    case activityDuration
    case movement
    case food
    case reflection

    var title: String {
        switch self {
        case .weight:
            return "Weight"
        case .waist:
            return "Waist circumference"
        case .bloodPressureChoice, .bloodPressureSystolic, .bloodPressureDiastolic, .bloodPressureDate:
            return "Blood pressure (Optional)"
        case .sleep:
            return "Sleep"
        case .activity:
            return "Physical activity"
        case .activityType:
            return "Activity type"
        case .activityDuration:
            return "Activity duration"
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
            return "Please enter your current weight."
        case .waist:
            return "Please enter your waist circumference."
        case .bloodPressureChoice:
            return "If you measured your blood pressure recently, enter the reading below."
        case .bloodPressureSystolic:
            return "What was the systolic blood pressure number?"
        case .bloodPressureDiastolic:
            return "What was the diastolic blood pressure number?"
        case .bloodPressureDate:
            return "When was this blood pressure reading measured?"
        case .sleep:
            return "About how many hours did you sleep last night? *"
        case .activity:
            return "Were you physically active today? *"
        case .activityType:
            return "Tell us about your activity. What type of activity did you do? *"
        case .activityDuration:
            return "How many minutes did that activity last? *"
        case .movement:
            return "During periods when you were sitting, how often did you stand up or walk for at least 2-3 minutes today? *"
        case .food:
            return "Would you like to add a food journal for today? (Optional)"
        case .reflection:
            return "After entering today's data, what did you notice about how your routines, behaviors, or body may be related to your metabolic health or insulin resistance risk today? *"
        }
    }
}

private struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

private struct AIChatBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.isUser {
                Spacer(minLength: 48)
                bubble
            } else {
                CloudyMascotView(size: 48)
                bubble
                Spacer(minLength: 48)
            }
        }
    }

    private var bubble: some View {
        Text(message.text)
            .font(.body)
            .foregroundStyle(message.isUser ? .white : AppColor.text)
            .lineSpacing(4)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(message.isUser ? AppColor.blue : AppColor.softViolet)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct AICheckInView: View {
    private enum FocusedInput: Hashable {
        case answer
        case foodDescription
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedInput: FocusedInput?
    @State private var typedAnswer = ""
    @State private var selectedOption: String?
    @State private var step: AIQuestionStep = .weight
    @State private var isShowingHealthImport = false
    @State private var missingItems: [MissingDataItem] = []
    @State private var isShowingMissingDataWarning = false
    @State private var selectedFoodPhotos: [PhotosPickerItem] = []
    @State private var foodPhotoBase64: [String] = []
    @State private var isFoodDescriptionVisible = false
    @State private var foodDescriptionDraft = ""
    @State private var chatMessages: [AIChatMessage] = []
    @State private var isReviewingSummary = false
    private var greetingName: String {
        let trimmedName = store.accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "there" : trimmedName
    }
    private var firstStep: AIQuestionStep {
        orderedSteps.first ?? .sleep
    }
    private var orderedSteps: [AIQuestionStep] {
        var steps: [AIQuestionStep] = []
        if store.shouldShowWeeklyCheckIn {
            steps += [.weight, .waist, .bloodPressureChoice]
            if store.checkIn.hasRecentBloodPressure {
                steps += [.bloodPressureSystolic, .bloodPressureDiastolic, .bloodPressureDate]
            }
        }
        steps += [.sleep, .activity]
        if store.checkIn.activeToday == true {
            steps += [.activityType, .activityDuration]
        }
        steps += [.movement, .food, .reflection]
        return steps
    }
    private var totalQuestionCount: Int {
        orderedSteps.count
    }
    private var progressIndex: Int {
        (orderedSteps.firstIndex(of: step) ?? 0) + 1
    }
    private var progressText: String {
        "\(progressIndex) of \(totalQuestionCount)"
    }
    private var progressValue: Double {
        Double(progressIndex) / Double(totalQuestionCount)
    }
    private var canMoveBack: Bool {
        guard let currentIndex = orderedSteps.firstIndex(of: step) else {
            return false
        }
        return currentIndex > orderedSteps.startIndex
    }
    private var foodNutritionNeedsMoreDetail: Bool {
        store.checkIn.foodNutritionSource == "unable_to_estimate"
            || store.nutritionEstimateMessage.contains("could not be estimated")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            progressHeader
            if focusedInput == nil {
                topActions
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(chatMessages) { message in
                            AIChatBubble(message: message)
                                .id(message.id)
                        }

                        if !isReviewingSummary && !quickReplies.isEmpty {
                            quickReplyRow
                        }

                        if !isReviewingSummary && step == .food {
                            foodJournalPanel
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("conversation-bottom")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chatMessages) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    withAnimation {
                        proxy.scrollTo("conversation-bottom", anchor: .bottom)
                    }
                }
                .onChange(of: focusedInput) { _, newValue in
                    guard newValue != nil else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation {
                            proxy.scrollTo("conversation-bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 14) {
                if isReviewingSummary {
                    OutlineButton(title: "Back") {
                        isReviewingSummary = false
                        move(to: .reflection)
                    }
                    PrimaryButton(title: "Submit Check-in") {
                        submitReviewedCheckIn()
                    }
                } else {
                    if canMoveBack {
                        Button {
                            moveToPreviousStep()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.headline)
                                .foregroundStyle(AppColor.blue)
                                .frame(width: 92, height: 56)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.blue, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                    TextField(textPlaceholder, text: $typedAnswer, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(AppTextFieldStyle())
                        .focused($focusedInput, equals: .answer)
                        .onSubmit {
                            submitTypedAnswer()
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
            }
            .padding(.horizontal, 22)
            .padding(.vertical, focusedInput == nil ? 18 : 10)
            .overlay(alignment: .top) {
                Rectangle().fill(AppColor.line).frame(height: 1)
            }

            if focusedInput == nil {
                BottomTabBar()
            }
        }
        .background(.white)
        .animation(.easeInOut(duration: 0.2), value: focusedInput)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedInput = nil
                }
            }
        }
        .sheet(isPresented: $isShowingHealthImport) {
            AppleHealthImportSheet { result in
                store.applyHealthImport(result)
                store.saveCheckIn(in: modelContext)
                isShowingHealthImport = false
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            if let requestedField = store.requestedCheckInField {
                move(to: stepForMissingField(requestedField))
                store.requestedCheckInField = nil
            } else if !store.checkIn.isCompleted, let firstMissing = store.checkInMissingDataItems().first {
                move(to: stepForMissingField(firstMissing.field))
            } else if !orderedSteps.contains(step) {
                move(to: firstStep)
            }
            foodDescriptionDraft = store.checkIn.foodJournalDescription
            isFoodDescriptionVisible = !store.checkIn.foodJournalDescription
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            initializeConversationIfNeeded()
        }
    }

    private var cloudyMessage: String {
        switch step {
        case .weight:
            return "Hi \(greetingName)! I’ll ask each required check-in question one at a time."
        case .waist:
            return "Thanks. This helps keep today’s check-in complete before feedback is generated."
        case .bloodPressureChoice:
            return "Blood pressure is optional. If you do not have a recent reading, we’ll skip it."
        case .bloodPressureSystolic, .bloodPressureDiastolic, .bloodPressureDate:
            return "Since you said you have a recent reading, I’ll collect the same details as the manual form."
        case .sleep:
            return "Got it. Now let’s check in on last night’s sleep."
        case .activityType, .activityDuration:
            return "Thanks. Since you were active today, activity type and duration are required."
        case .food:
            return "This part is optional. I won’t guess if you leave it blank."
        case .reflection:
            return "One last required question. A short sentence is enough."
        default:
            return "Got it. Let’s keep going."
        }
    }

    private var textPlaceholder: String {
        switch step {
        case .weight:
            return "e.g., 165 lb or 75 kg"
        case .waist:
            return "e.g., 34 in or 86 cm"
        case .bloodPressureChoice:
            return "e.g., yes or no"
        case .bloodPressureSystolic:
            return "e.g., 120"
        case .bloodPressureDiastolic:
            return "e.g., 80"
        case .bloodPressureDate:
            return "e.g., Today"
        case .sleep:
            return "e.g., 6.5 hours"
        case .activity:
            return "e.g., yes or no"
        case .activityType:
            return "e.g., brisk walking"
        case .activityDuration:
            return "e.g., 20"
        case .movement:
            return "Type your answer..."
        case .food:
            return "e.g., chicken rice and an apple"
        case .reflection:
            return "e.g., I felt more tired than usual..."
        }
    }

    private var quickReplies: [String] {
        switch step {
        case .bloodPressureChoice:
            return ["I have a recent reading", "I don't have a recent reading"]
        case .activity:
            return ["Yes", "No"]
        case .food:
            return ["Skip food journal"]
        default:
            return []
        }
    }

    private var quickReplyRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(quickReplies, id: \.self) { reply in
                    Button {
                        choose(reply)
                    } label: {
                        Text(reply)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.blue)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(AppColor.sky)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func initializeConversationIfNeeded() {
        guard chatMessages.isEmpty else { return }
        appendAssistant(questionMessage(for: step))
    }

    private func appendAssistant(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if chatMessages.last?.text == trimmed && chatMessages.last?.isUser == false {
            return
        }
        chatMessages.append(AIChatMessage(text: trimmed, isUser: false))
    }

    private func appendUser(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatMessages.append(AIChatMessage(text: trimmed, isUser: true))
    }

    private func questionMessage(for targetStep: AIQuestionStep) -> String {
        switch targetStep {
        case .weight:
            return "Hi \(greetingName), let's do today's check-in together. What's your current weight?"
        case .waist:
            return "What's your waist circumference?"
        case .bloodPressureChoice:
            return "Do you have a recent blood pressure reading you want to include? You can say yes or no."
        case .bloodPressureSystolic:
            return "What was the systolic number?"
        case .bloodPressureDiastolic:
            return "What was the diastolic number?"
        case .bloodPressureDate:
            return "When was that blood pressure reading measured?"
        case .sleep:
            return "About how many hours did you sleep last night?"
        case .activity:
            return "Were you physically active today?"
        case .activityType:
            return "What kind of activity did you do?"
        case .activityDuration:
            return "About how many minutes did that activity last?"
        case .movement:
            return "When you were sitting today, how often did you stand up or walk for a few minutes?"
        case .food:
            return "Optional food journal: describe what you ate and drank, upload photos, or skip this part."
        case .reflection:
            return "Last one: what did you notice today about your routines, body, energy, food, sleep, or movement?"
        }
    }

    private func clarifyingPrompt(for targetStep: AIQuestionStep) -> String {
        switch targetStep {
        case .weight:
            return "Please include a number, like 165 lb or 75 kg."
        case .waist:
            return "Please include a number, like 34 in or 86 cm."
        case .bloodPressureChoice:
            return "Please answer yes or no."
        case .bloodPressureSystolic:
            return "Please enter the top blood pressure number, like 120."
        case .bloodPressureDiastolic:
            return "Please enter the bottom blood pressure number, like 80."
        case .bloodPressureDate:
            return "You can write something like today, yesterday, or Sep 10."
        case .sleep:
            return "Please include the number of hours, like 6.5 hours."
        case .activity:
            return "Please answer yes or no."
        case .activityType:
            return "A short phrase is enough, like walking, cycling, or strength training."
        case .activityDuration:
            return "Please include minutes, like 20 min."
        case .movement:
            return "You can say hourly, a few times, once, not at all, or not much sitting."
        case .food:
            return "You can describe the food or tap Skip food journal."
        case .reflection:
            return "A short sentence is enough."
        }
    }

    private func fieldForStep(_ targetStep: AIQuestionStep) -> String {
        switch targetStep {
        case .weight:
            return "weight"
        case .waist:
            return "waist_circumference"
        case .bloodPressureChoice:
            return "blood_pressure_optional_choice"
        case .bloodPressureSystolic:
            return "systolic_bp"
        case .bloodPressureDiastolic:
            return "diastolic_bp"
        case .bloodPressureDate:
            return "blood_pressure_date"
        case .sleep:
            return "sleep_hours"
        case .activity:
            return "physical_activity_today"
        case .activityType:
            return "activity_type"
        case .activityDuration:
            return "activity_duration"
        case .movement:
            return "movement_breaks"
        case .food:
            return "food_journal"
        case .reflection:
            return "daily_reflection"
        }
    }

    private func applyCorrectionIfNeeded(_ answer: String) -> Bool {
        let lowercased = answer.lowercased()
        let soundsLikeCorrection = lowercased.contains("actually")
            || lowercased.contains("change")
            || lowercased.contains("update")
            || lowercased.contains("edit")
            || lowercased.contains("correct")
        guard soundsLikeCorrection else {
            return false
        }

        if lowercased.contains("sleep"), let hours = firstNumber(in: answer) {
            store.checkIn.sleepHours = formatNumber(hours)
            store.saveCheckIn(in: modelContext)
            appendAssistant("Updated sleep to \(store.checkIn.sleepHours) hours. \(questionMessage(for: step))")
            return true
        }
        if lowercased.contains("weight"), let weight = firstNumber(in: answer) {
            store.checkIn.weight = formatNumber(weight)
            store.checkIn.weightUnit = normalizedWeightUnit(from: answer)
            store.saveCheckIn(in: modelContext)
            appendAssistant("Updated weight to \(store.checkIn.weight) \(store.checkIn.weightUnit). \(questionMessage(for: step))")
            return true
        }
        if lowercased.contains("waist"), let waist = firstNumber(in: answer) {
            store.checkIn.waist = formatNumber(waist)
            store.checkIn.waistUnit = normalizedWaistUnit(from: answer)
            store.saveCheckIn(in: modelContext)
            appendAssistant("Updated waist circumference to \(store.checkIn.waist) \(store.checkIn.waistUnit). \(questionMessage(for: step))")
            return true
        }
        if lowercased.contains("activity") || lowercased.contains("exercise") || lowercased.contains("workout") {
            if let minutes = firstNumber(in: answer) {
                store.checkIn.activityDuration = "\(Int(minutes.rounded()))"
            }
            let normalized = normalizedActivityType(answer)
            if normalized != answer
                || lowercased.contains("walk")
                || lowercased.contains("run")
                || lowercased.contains("cycle")
                || lowercased.contains("bike")
                || lowercased.contains("swim")
                || lowercased.contains("strength")
                || lowercased.contains("yoga") {
                store.checkIn.activeToday = true
                store.checkIn.activityType = normalized
            }
            store.saveCheckIn(in: modelContext)
            appendAssistant("Updated your activity. \(questionMessage(for: step))")
            return true
        }
        if lowercased.contains("movement") || lowercased.contains("break") || lowercased.contains("sitting") {
            store.checkIn.movementBreaks = normalizedMovementAnswer(answer)
            store.saveCheckIn(in: modelContext)
            appendAssistant("Updated movement breaks. \(questionMessage(for: step))")
            return true
        }
        return false
    }

    private var foodJournalPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add food journal")
                .font(.headline)
                .foregroundStyle(AppColor.text)
            Text("Upload up to 4 photos from one or more meals. We will try to identify the foods and automatically estimate today's total calories and nutrients. You do not need to enter calories yourself; adding food names and approximate portions can improve the estimate.")
                .font(.callout)
                .foregroundStyle(AppColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedFoodPhotos, maxSelectionCount: 4, matching: .images) {
                    FoodJournalActionButton(
                        icon: "photo.on.rectangle",
                        title: selectedFoodPhotos.isEmpty ? "Upload Photos" : "\(selectedFoodPhotos.count) Photo\(selectedFoodPhotos.count == 1 ? "" : "s") Selected"
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: selectedFoodPhotos) { _, newValue in
                    commitFoodDescription()
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
                    foodDescriptionDraft = store.checkIn.foodJournalDescription
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
                    TextEditor(text: $foodDescriptionDraft)
                        .focused($focusedInput, equals: .foodDescription)
                        .frame(minHeight: 92)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
                    Button {
                        commitFoodDescription()
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
                Label(
                    store.nutritionEstimateMessage,
                    systemImage: foodNutritionNeedsMoreDetail ? "exclamationmark.triangle" : "checkmark.seal"
                )
                    .font(.caption)
                    .foregroundStyle(foodNutritionNeedsMoreDetail ? Color.orange : AppColor.muted)
            }

            if foodNutritionNeedsMoreDetail {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add the food names and approximate portions, then try again. Your written food note and photo count are saved, but the photo files are not stored with your check-in.")
                        .font(.callout)
                        .foregroundStyle(AppColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        isFoodDescriptionVisible = true
                        foodDescriptionDraft = store.checkIn.foodJournalDescription
                        DispatchQueue.main.async {
                            focusedInput = .foodDescription
                        }
                    } label: {
                        Label("Add meal details and try again", systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Label("We estimate nutrition by matching your food notes or identified foods from photos to USDA FoodData Central, then adjusting calories and macros based on portion size. Estimates may be imperfect and are for reflection only.", systemImage: "info.circle")
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
        appendUser(option)
        switch step {
        case .weight, .waist:
            return
        case .bloodPressureChoice:
            if option == "I have a recent reading" {
                store.checkIn.hasRecentBloodPressure = true
                appendAssistant("Got it. I'll collect the blood pressure numbers next.")
            } else {
                store.checkIn.hasRecentBloodPressure = false
                store.checkIn.systolic = ""
                store.checkIn.diastolic = ""
                store.checkIn.bloodPressureDate = ""
                appendAssistant("No problem. I'll skip blood pressure for today.")
            }
            moveToNextStep()
        case .bloodPressureSystolic, .bloodPressureDiastolic, .bloodPressureDate:
            return
        case .sleep:
            store.checkIn.sleepHours = option.replacingOccurrences(of: " hr", with: "")
            appendAssistant("Got it: \(store.checkIn.sleepHours) hours of sleep.")
            moveToNextStep()
        case .activity:
            if option == "Yes" {
                store.checkIn.activeToday = true
                appendAssistant("Great. What kind of activity did you do?")
            } else {
                store.checkIn.activeToday = false
                store.checkIn.activityType = ""
                store.checkIn.activityDuration = ""
                appendAssistant("Got it. I'll record no physical activity for today.")
            }
            moveToNextStep()
        case .activityType:
            store.checkIn.activityType = option
            appendAssistant("Recorded: \(store.checkIn.activityType).")
            moveToNextStep()
        case .activityDuration:
            store.checkIn.activityDuration = option.replacingOccurrences(of: " min", with: "")
            appendAssistant("Recorded: \(store.checkIn.activityDuration) minutes.")
            moveToNextStep()
        case .movement:
            store.checkIn.movementBreaks = option
            appendAssistant("Thanks, I saved that movement-break answer.")
            moveToNextStep()
        case .food:
            if option == "Skip food journal" {
                skipFoodJournal()
                return
            }
            moveToNextStep()
        case .reflection:
            completeWithValidation()
        }
    }

    private func submitTypedAnswer() {
        let answer = typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else {
            showMissing(field: fieldForStep(step), label: step.title)
            return
        }
        appendUser(answer)
        typedAnswer = ""
        focusedInput = nil
        if applyCorrectionIfNeeded(answer) {
            return
        }
        switch step {
        case .weight:
            guard let weight = firstNumber(in: answer) else {
                showMissing(field: "weight", label: "Weight")
                return
            }
            store.checkIn.weight = formatNumber(weight)
            store.checkIn.weightUnit = normalizedWeightUnit(from: answer)
            appendAssistant("Got it: \(store.checkIn.weight) \(store.checkIn.weightUnit).")
            moveToNextStep()
        case .waist:
            guard let waist = firstNumber(in: answer) else {
                showMissing(field: "waist_circumference", label: "Waist circumference")
                return
            }
            store.checkIn.waist = formatNumber(waist)
            store.checkIn.waistUnit = normalizedWaistUnit(from: answer)
            appendAssistant("Thanks, I recorded \(store.checkIn.waist) \(store.checkIn.waistUnit) for waist circumference.")
            moveToNextStep()
        case .bloodPressureChoice:
            let lowercased = answer.lowercased()
            if lowercased.contains("yes") || lowercased.contains("have") || lowercased.contains("recent") {
                store.checkIn.hasRecentBloodPressure = true
                appendAssistant("Got it. I'll ask for the blood pressure numbers.")
                moveToNextStep()
            } else if lowercased.contains("no") || lowercased.contains("don't") || lowercased.contains("do not") || lowercased.contains("none") {
                store.checkIn.hasRecentBloodPressure = false
                store.checkIn.systolic = ""
                store.checkIn.diastolic = ""
                store.checkIn.bloodPressureDate = ""
                appendAssistant("No problem. I'll skip blood pressure for today.")
                moveToNextStep()
            } else {
                showMissing(field: "blood_pressure_optional_choice", label: "Blood pressure optional choice")
            }
        case .bloodPressureSystolic:
            guard let systolic = firstNumber(in: answer) else {
                showMissing(field: "systolic_bp", label: "Systolic blood pressure")
                return
            }
            store.checkIn.systolic = formatNumber(systolic)
            appendAssistant("Recorded systolic blood pressure: \(store.checkIn.systolic).")
            moveToNextStep()
        case .bloodPressureDiastolic:
            guard let diastolic = firstNumber(in: answer) else {
                showMissing(field: "diastolic_bp", label: "Diastolic blood pressure")
                return
            }
            store.checkIn.diastolic = formatNumber(diastolic)
            appendAssistant("Recorded diastolic blood pressure: \(store.checkIn.diastolic).")
            moveToNextStep()
        case .bloodPressureDate:
            store.checkIn.bloodPressureDate = answer.isEmpty ? "Today" : answer
            appendAssistant("Thanks. I saved the blood pressure date as \(store.checkIn.bloodPressureDate).")
            moveToNextStep()
        case .sleep:
            guard let hours = firstNumber(in: answer) else {
                showMissing(field: "sleep_hours", label: "Sleep duration")
                return
            }
            store.checkIn.sleepHours = formatNumber(hours)
            appendAssistant("Got it: \(store.checkIn.sleepHours) hours of sleep.")
            moveToNextStep()
        case .activity:
            let lowercased = answer.lowercased()
            if lowercased.contains("yes") || lowercased.contains("active") {
                store.checkIn.activeToday = true
                appendAssistant("Great. What kind of activity did you do?")
                moveToNextStep()
            } else if lowercased.contains("no") || lowercased.contains("not") {
                store.checkIn.activeToday = false
                store.checkIn.activityType = ""
                store.checkIn.activityDuration = ""
                appendAssistant("Got it. I'll record no physical activity for today.")
                moveToNextStep()
            } else {
                showMissing(field: "physical_activity_today", label: "Physical activity")
            }
        case .activityType:
            guard !answer.isEmpty else {
                showMissing(field: "activity_type", label: "Activity type")
                return
            }
            store.checkIn.activityType = normalizedActivityType(answer)
            appendAssistant("Recorded: \(store.checkIn.activityType).")
            moveToNextStep()
        case .activityDuration:
            guard let minutes = firstNumber(in: answer) else {
                showMissing(field: "activity_duration", label: "Activity duration")
                return
            }
            store.checkIn.activityDuration = "\(Int(minutes.rounded()))"
            appendAssistant("Recorded: \(store.checkIn.activityDuration) minutes.")
            moveToNextStep()
        case .movement:
            guard !answer.isEmpty else {
                showMissing(field: "movement_breaks", label: "Movement breaks")
                return
            }
            store.checkIn.movementBreaks = normalizedMovementAnswer(answer)
            appendAssistant("Thanks, I saved that movement-break answer.")
            moveToNextStep()
        case .food:
            if !answer.isEmpty {
                store.checkIn.foodJournal = "Added"
                store.checkIn.foodJournalDescription = answer
                foodDescriptionDraft = answer
                appendAssistant("I added that to your food journal and will estimate nutrition from it.")
            }
            continueFromFoodJournal()
        case .reflection:
            guard !answer.isEmpty else {
                showMissing(field: "daily_reflection", label: "Daily reflection")
                return
            }
            store.checkIn.dailyReflection = answer
            appendAssistant("Thanks. I saved your reflection.")
            completeWithValidation()
        }
    }

    private func updateFoodJournalStatus() {
        let hasDescription = !foodDescriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !store.checkIn.foodJournalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func commitFoodDescription() {
        let draft = foodDescriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.checkIn.foodJournalDescription != draft {
            store.checkIn.foodJournalDescription = draft
        }
        updateFoodJournalStatus()
    }

    private func estimateFoodAndContinue() {
        commitFoodDescription()
        let description = store.checkIn.foodJournalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty || !foodPhotoBase64.isEmpty {
            store.checkIn.foodJournal = "Added"
            store.estimateFoodNutrition(text: description, imageBase64: foodPhotoBase64)
        }
        moveToNextStep()
    }

    private func continueFromFoodJournal() {
        commitFoodDescription()
        let description = store.checkIn.foodJournalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty || store.checkIn.foodPhotoCount > 0 {
            store.checkIn.foodJournal = "Added"
            if !description.isEmpty || !foodPhotoBase64.isEmpty {
                store.estimateFoodNutrition(text: description, imageBase64: foodPhotoBase64)
            }
        } else if store.checkIn.foodJournal != "Skipped" {
            store.checkIn.foodJournal = ""
        }
        moveToNextStep()
    }

    private func skipFoodJournal() {
        selectedFoodPhotos = []
        foodPhotoBase64 = []
        isFoodDescriptionVisible = false
        foodDescriptionDraft = ""
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
        moveToNextStep()
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
        step = nextStep
        typedAnswer = savedAnswerText(for: nextStep)
        selectedOption = savedOption(for: nextStep)
        store.saveCheckIn(in: modelContext)
        appendAssistant(questionMessage(for: nextStep))
    }

    private func moveToNextStep() {
        guard let currentIndex = orderedSteps.firstIndex(of: step) else {
            move(to: firstStep)
            return
        }
        let nextIndex = orderedSteps.index(after: currentIndex)
        guard orderedSteps.indices.contains(nextIndex) else {
            completeWithValidation()
            return
        }
        move(to: orderedSteps[nextIndex])
    }

    private func moveToPreviousStep() {
        guard let currentIndex = orderedSteps.firstIndex(of: step), currentIndex > orderedSteps.startIndex else {
            return
        }
        let previousIndex = orderedSteps.index(before: currentIndex)
        move(to: orderedSteps[previousIndex])
    }

    private func savedAnswerText(for targetStep: AIQuestionStep) -> String {
        switch targetStep {
        case .weight:
            return formattedMeasurement(value: store.checkIn.weight, unit: store.checkIn.weightUnit)
        case .waist:
            return formattedMeasurement(value: store.checkIn.waist, unit: store.checkIn.waistUnit)
        case .bloodPressureChoice:
            if store.checkIn.hasRecentBloodPressure { return "Yes" }
            return ""
        case .bloodPressureSystolic:
            return store.checkIn.systolic
        case .bloodPressureDiastolic:
            return store.checkIn.diastolic
        case .bloodPressureDate:
            return store.checkIn.bloodPressureDate
        case .sleep:
            return store.checkIn.sleepHours
        case .activity:
            guard let activeToday = store.checkIn.activeToday else { return "" }
            return activeToday ? "Yes" : "No"
        case .activityType:
            return store.checkIn.activityType
        case .activityDuration:
            return store.checkIn.activityDuration
        case .movement:
            return store.checkIn.movementBreaks
        case .food:
            return store.checkIn.foodJournalDescription
        case .reflection:
            return store.checkIn.dailyReflection
        }
    }

    private func savedOption(for targetStep: AIQuestionStep) -> String? {
        switch targetStep {
        case .bloodPressureChoice:
            return store.checkIn.hasRecentBloodPressure ? "I have a recent reading" : nil
        case .activity:
            guard let activeToday = store.checkIn.activeToday else { return nil }
            return activeToday ? "Yes" : "No"
        default:
            return nil
        }
    }

    private func formattedMeasurement(value: String, unit: String) -> String {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return "\(value) \(unit)"
    }

    private func showMissing(field: String, label: String) {
        missingItems = [
            MissingDataItem(field: field, label: label, code: MissingDataCode.missing)
        ]
        appendAssistant("I couldn't read \(label.lowercased()) from that. \(clarifyingPrompt(for: step))")
    }

    private func navigateToFirstMissingItem() {
        if let firstMissing = missingItems.first {
            move(to: stepForMissingField(firstMissing.field))
        }
    }

    private func stepForMissingField(_ field: String) -> AIQuestionStep {
        switch field {
        case "weight":
            return .weight
        case "waist_circumference":
            return .waist
        case "systolic_bp":
            return .bloodPressureSystolic
        case "diastolic_bp":
            return .bloodPressureDiastolic
        case "blood_pressure_date":
            return .bloodPressureDate
        case "sleep_hours":
            return .sleep
        case "physical_activity_today":
            return .activity
        case "activity_type":
            return .activityType
        case "activity_duration":
            return .activityDuration
        case "movement_breaks":
            return .movement
        case "daily_reflection":
            return .reflection
        default:
            return firstStep
        }
    }

    private func completeWithValidation() {
        let items = store.checkInMissingDataItems()
        guard items.isEmpty else {
            missingItems = items
            if let firstMissing = items.first {
                let missingStep = stepForMissingField(firstMissing.field)
                move(to: missingStep)
                appendAssistant("Before I can finish, I still need \(firstMissing.label.lowercased()).")
            }
            return
        }
        store.saveCheckIn(in: modelContext)
        isReviewingSummary = true
        appendAssistant(reviewSummaryMessage)
    }

    private func submitReviewedCheckIn() {
        store.checkIn.isCompleted = true
        store.saveCheckIn(in: modelContext)
        store.screen = .completion
    }

    private var reviewSummaryMessage: String {
        let activity: String
        if store.checkIn.activeToday == false {
            activity = "No physical activity"
        } else {
            let type = store.checkIn.activityType.trimmingCharacters(in: .whitespacesAndNewlines)
            let duration = store.checkIn.activityDuration.trimmingCharacters(in: .whitespacesAndNewlines)
            activity = [type, duration.isEmpty ? "" : "\(duration) min"]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
        return """
        Here is today's check-in summary:
        Sleep: \(emptyFallback(store.checkIn.sleepHours, suffix: "hr"))
        Activity: \(activity.isEmpty ? "Not logged" : activity)
        Movement breaks: \(emptyFallback(store.checkIn.movementBreaks))
        Food journal: \(store.checkIn.foodJournalSummary)
        Reflection: \(emptyFallback(store.checkIn.dailyReflection))
        """
    }

    private func emptyFallback(_ value: String, suffix: String = "") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Not logged"
        }
        return suffix.isEmpty ? trimmed : "\(trimmed) \(suffix)"
    }

    private func normalizedActivityType(_ text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains("strength") || lowercased.contains("weight") {
            return "Strength training"
        }
        if lowercased.contains("run") {
            return "Running"
        }
        if lowercased.contains("cycle") || lowercased.contains("bike") {
            return "Cycling"
        }
        if lowercased.contains("swim") {
            return "Swimming"
        }
        if lowercased.contains("walk") {
            return "Brisk walking"
        }
        if lowercased.contains("yoga") || lowercased.contains("stretch") {
            return "Yoga or stretching"
        }
        if lowercased.contains("sport") {
            return "Sports"
        }
        return text
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
                Text(progressText)
            }
            .font(.title3)
            .foregroundStyle(AppColor.text)
            ProgressView(value: progressValue)
                .tint(AppColor.blue)
        }
        .padding(24)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColor.line).frame(height: 1)
        }
    }
}
