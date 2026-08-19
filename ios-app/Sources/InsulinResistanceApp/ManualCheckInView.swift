import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ManualCheckInView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @State private var step = 1
    @State private var isShowingHealthImport = false
    @State private var missingItems: [MissingDataItem] = []
    @State private var isShowingMissingDataWarning = false
    @State private var selectedFoodPhotos: [PhotosPickerItem] = []
    @State private var foodPhotoBase64: [String] = []
    @State private var isFoodJournalDescriptionVisible = false
    @State private var isShowingActivityPrototypeNote = false
    @State private var additionalActivities: [AdditionalActivityDraft] = []
    private var totalSteps: Int {
        store.shouldShowWeeklyCheckIn ? 4 : 3
    }

    private var stepLabels: [String] {
        store.shouldShowWeeklyCheckIn
            ? ["Weekly", "Sleep", "Activity", "Reflection"]
            : ["Sleep", "Activity", "Reflection"]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    topActions
                    StepIndicator(currentStep: step, labels: stepLabels)
                    stageIntro
                    currentStepContent

                    HStack(spacing: 14) {
                        if step > 1 {
                            OutlineButton(title: "Back") {
                                step -= 1
                            }
                        }
                        PrimaryButton(title: step == totalSteps ? "Review check-in" : "Continue") {
                            continueWithValidation()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Button("OK", role: .cancel) {}
        } message: {
            Text(missingDataMessage)
        }
        .onAppear {
            isFoodJournalDescriptionVisible = !store.checkIn.foodJournalDescription
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }
    }

    private var missingDataMessage: String {
        if missingItems.isEmpty { return "" }
        let labels = missingItems.map { "\($0.label): \($0.code)" }.joined(separator: "\n")
        return "Please answer the required question\(missingItems.count == 1 ? "" : "s") before continuing.\n\n\(labels)"
    }

    private func continueWithValidation() {
        missingItems = currentStepMissingDataItems()
        if missingItems.isEmpty {
            if step == totalSteps {
                missingItems = store.checkInMissingDataItems()
                guard missingItems.isEmpty else {
                    isShowingMissingDataWarning = true
                    return
                }
                store.checkIn.isCompleted = true
                store.saveCheckIn(in: modelContext)
                store.screen = .completion
            } else {
                store.saveCheckIn(in: modelContext)
                step += 1
            }
        } else {
            isShowingMissingDataWarning = true
        }
    }

    private func currentStepMissingDataItems() -> [MissingDataItem] {
        var items: [MissingDataItem] = []
        switch currentStage {
        case 1:
            addRequiredString(&items, field: "weight", label: "Weight", value: store.checkIn.weight)
            addRequiredString(&items, field: "waist_circumference", label: "Waist circumference", value: store.checkIn.waist)
            if store.checkIn.hasRecentBloodPressure {
                addRequiredString(&items, field: "systolic_bp", label: "Systolic blood pressure", value: store.checkIn.systolic)
                addRequiredString(&items, field: "diastolic_bp", label: "Diastolic blood pressure", value: store.checkIn.diastolic)
                addRequiredString(&items, field: "blood_pressure_date", label: "Blood pressure date measured", value: store.checkIn.bloodPressureDate)
            }
        case 2:
            addRequiredString(&items, field: "sleep_hours", label: "Sleep duration", value: store.checkIn.sleepHours)
        case 3:
            if store.checkIn.activeToday == nil {
                items.append(MissingDataItem(field: "physical_activity_today", label: "Physical activity", code: MissingDataCode.missing))
            } else if store.checkIn.activeToday == true {
                addRequiredString(&items, field: "activity_type", label: "Activity type", value: store.checkIn.activityType)
                addRequiredString(&items, field: "activity_duration", label: "Activity duration", value: store.checkIn.activityDuration)
            }
        default:
            addRequiredString(&items, field: "movement_breaks", label: "Movement breaks", value: store.checkIn.movementBreaks)
            addRequiredString(&items, field: "daily_reflection", label: "Daily reflection", value: store.checkIn.dailyReflection)
        }
        return items
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch currentStage {
        case 1:
            bodyStep
        case 2:
            habitsStep
        case 3:
            activityStep
        default:
            reflectionStep
        }
    }

    private var currentStage: Int {
        store.shouldShowWeeklyCheckIn ? step : step + 1
    }

    private func addRequiredString(_ items: inout [MissingDataItem], field: String, label: String, value: String) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(MissingDataItem(field: field, label: label, code: MissingDataCode.missing))
        }
    }

    private var header: some View {
        HStack {
            Text("Today's check-in")
                .font(.title2.bold())
            Spacer()
            Label("About 3 min", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(AppColor.text)
        }
        .padding(.top, 20)
    }

    private var topActions: some View {
        VStack(spacing: 10) {
            AppleHealthRow {
                isShowingHealthImport = true
            }

            Button {
                store.screen = .aiCheckIn
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title3)
                        .foregroundStyle(AppColor.blue)
                        .frame(width: 42, height: 42)
                        .background(Color.blue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Switch to AI input")
                            .font(.headline)
                            .foregroundStyle(AppColor.text)
                        Text("Talk or type with Cloudy instead")
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
    }

    private var stageIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            if currentStage == 1 {
                Text("These weekly measurements help us update your estimated risk related to insulin resistance and show changes over time.")
            } else {
                Text("Required questions are marked with an asterisk (*). Only blood pressure and food journal are optional.")
            }
        }
        .font(.callout)
        .foregroundStyle(AppColor.text)
        .padding(14)
        .background(AppColor.sky)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var bodyStep: some View {
        VStack(spacing: 14) {
            WeeklyMeasurementBadge()
            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Please enter your current weight.")
                        .font(.callout)
                        .foregroundStyle(AppColor.text)
                    FormField(title: "Weight *", text: $store.checkIn.weight, placeholder: "Enter weight")
                    Picker("Weight unit", selection: $store.checkIn.weightUnit) {
                        Text("lb").tag("lb")
                        Text("kg").tag("kg")
                    }
                    .pickerStyle(.segmented)
                }
            }
            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    FormField(title: "Waist circumference *", text: $store.checkIn.waist, placeholder: "Enter waist")
                    Picker("Waist unit", selection: $store.checkIn.waistUnit) {
                        Text("in").tag("in")
                        Text("cm").tag("cm")
                    }
                    .pickerStyle(.segmented)
                    Text("Measure around your waist just above your hip bones. Keep the tape snug, but do not compress your skin.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Most recent blood pressure reading (Optional)")
                        .font(.headline)
                    Text("If you measured your blood pressure recently, enter the reading below.")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)
                    Toggle("I have a recent reading", isOn: $store.checkIn.hasRecentBloodPressure)
                    if store.checkIn.hasRecentBloodPressure {
                        HStack {
                            TextField("Systolic", text: $store.checkIn.systolic)
                                .textFieldStyle(AppTextFieldStyle())
                            Text("/")
                                .font(.title2)
                            TextField("Diastolic", text: $store.checkIn.diastolic)
                                .textFieldStyle(AppTextFieldStyle())
                        }
                        FormField(title: "Date measured", text: $store.checkIn.bloodPressureDate, placeholder: "e.g., Today")
                    } else {
                        Text("I don't have a recent reading.")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(AppColor.muted)
                    }
                }
            }
        }
    }

    private var habitsStep: some View {
        VStack(spacing: 14) {
            SectionCard {
                FormField(title: "About how many hours did you sleep last night? *", text: $store.checkIn.sleepHours, placeholder: "Enter hours")
            }
        }
    }

    private var activityStep: some View {
        VStack(spacing: 14) {
            YesNoCard(title: "Were you physically active today? *", value: $store.checkIn.activeToday)
            if store.checkIn.activeToday == true {
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tell us about your activity *")
                            .font(.headline)
                        Text("If you were active today, activity type and duration are required.")
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                        ActivityTypeMenu(selection: $store.checkIn.activityType, placeholder: "Activity type *")
                        FormField(title: "Duration (min) *", text: $store.checkIn.activityDuration, placeholder: "Enter minutes")
                        Text("e.g., brisk walking, cycling, swimming, strength training")
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                }
                ForEach($additionalActivities) { $activity in
                    AdditionalActivityCard(activity: $activity) {
                        additionalActivities.removeAll { $0.id == activity.id }
                    }
                }
                Button {
                    additionalActivities.append(AdditionalActivityDraft())
                } label: {
                    Text("+ Add another activity")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.blue, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
            } else {
                Text("No activity is a valid response for today's check-in.")
                    .font(.callout)
                    .foregroundStyle(AppColor.muted)
            }
        }
    }

    private var reflectionStep: some View {
        VStack(spacing: 14) {
            SectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("During periods when you were sitting, how often did you stand up or walk for at least 2-3 minutes today? *")
                        .font(.headline)
                    OptionGrid(
                        options: ["About once an hour or more", "A few times during the day", "Once", "Not at all", "I did not spend much time sitting today"],
                        selection: $store.checkIn.movementBreaks
                    )
                }
            }
            foodJournalCard
            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("After entering today's data, what did you notice about how your routines, behaviors, or body may be related to your metabolic health or insulin resistance risk today? *")
                        .font(.headline)
                    Text("Prompts: What stood out to you today? Did anything surprise you? Did you notice any connection among your activity, movement breaks, sleep, food, stress, energy, or symptoms?")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                    TextEditor(text: $store.checkIn.dailyReflection)
                        .frame(minHeight: 110)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
                }
            }
        }
    }

    private var foodJournalCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Would you like to add a food journal for today? (Optional)")
                    .font(.headline)
                Text("Upload photos or briefly describe what you ate and drank. You can use both methods and add anything that is not shown in your photos.")
                    .font(.callout)
                    .foregroundStyle(AppColor.muted)

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
                            store.estimateFoodNutrition(imageBase64: foodPhotoBase64)
                        }
                    }

                    Button {
                        isFoodJournalDescriptionVisible = true
                    } label: {
                        FoodJournalActionButton(
                            icon: "square.and.pencil",
                            title: "Describe What I Ate and Drank"
                        )
                    }
                    .buttonStyle(.plain)
                }

                if isFoodJournalDescriptionVisible {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Food journal notes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.text)
                        TextEditor(text: $store.checkIn.foodJournalDescription)
                            .frame(minHeight: 96)
                            .padding(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
                            .onChange(of: store.checkIn.foodJournalDescription) { _, _ in
                                updateFoodJournalStatus()
                            }
                        Button {
                            store.estimateFoodNutrition(
                                text: store.checkIn.foodJournalDescription,
                                imageBase64: foodPhotoBase64
                            )
                        } label: {
                            Label("Estimate nutrition from description", systemImage: "wand.and.stars")
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Estimated nutrition summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.text)
                    Text("Optional. Enter an estimate if you know it, or leave blank for later AI/database analysis.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)

                    nutritionEstimateStatus

                    Label("Nutrition values are estimates, not medical or dietary advice.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if store.checkIn.foodJournal == "Skipped" {
                        Label("Skipped for today. You can still add food details below.", systemImage: "checkmark.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.muted)
                    }

                    FormField(title: "Calories", text: $store.checkIn.foodCalories, placeholder: "e.g., 520")
                        .onChange(of: store.checkIn.foodCalories) { _, _ in updateFoodJournalStatus() }

                    HStack(spacing: 10) {
                        MacroField(title: "Carbs", text: $store.checkIn.foodCarbohydrates)
                            .onChange(of: store.checkIn.foodCarbohydrates) { _, _ in updateFoodJournalStatus() }
                        MacroField(title: "Protein", text: $store.checkIn.foodProtein)
                            .onChange(of: store.checkIn.foodProtein) { _, _ in updateFoodJournalStatus() }
                        MacroField(title: "Fat", text: $store.checkIn.foodFat)
                            .onChange(of: store.checkIn.foodFat) { _, _ in updateFoodJournalStatus() }
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

                    if !store.checkIn.foodNutritionExplanation.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            if !store.checkIn.foodNutritionMatchedFoods.isEmpty {
                                Text("Detected: \(store.checkIn.foodNutritionMatchedFoods)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColor.text)
                            }
                            Text(store.checkIn.foodNutritionExplanation)
                                .font(.caption)
                                .foregroundStyle(AppColor.muted)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button("Skip for Now") {
                    selectedFoodPhotos = []
                    foodPhotoBase64 = []
                    isFoodJournalDescriptionVisible = false
                    store.checkIn.foodPhotoCount = 0
                    store.checkIn.foodJournalDescription = ""
                    clearNutritionEstimate()
                    store.checkIn.foodJournal = "Skipped"
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.purple)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var nutritionEstimateStatus: some View {
        HStack(spacing: 8) {
            if store.isEstimatingNutrition {
                ProgressView()
                    .controlSize(.small)
                Text("Estimating from food input...")
            } else if !store.nutritionEstimateMessage.isEmpty {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(AppColor.blue)
                Text(store.nutritionEstimateMessage)
            } else if !store.checkIn.foodNutritionConfidence.isEmpty {
                Image(systemName: "info.circle")
                    .foregroundStyle(AppColor.blue)
                Text("Estimate confidence: \(store.checkIn.foodNutritionConfidence)")
            } else if store.checkIn.foodPhotoCount > 0 {
                Image(systemName: "photo")
                    .foregroundStyle(AppColor.blue)
                Text("Photo selected. Nutrition will be estimated automatically when the backend is available, or with a low-confidence local fallback.")
            } else {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppColor.blue)
                Text("Upload a photo or describe food to estimate calories and macros.")
            }
        }
        .font(.caption)
        .foregroundStyle(AppColor.muted)
        .fixedSize(horizontal: false, vertical: true)
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

    private func clearNutritionEstimate() {
        store.checkIn.foodCalories = ""
        store.checkIn.foodCarbohydrates = ""
        store.checkIn.foodProtein = ""
        store.checkIn.foodFat = ""
        store.checkIn.foodNutritionSource = ""
        store.checkIn.foodNutritionConfidence = ""
        store.checkIn.foodNutritionExplanation = ""
        store.checkIn.foodNutritionMatchedFoods = ""
        store.nutritionEstimateMessage = ""
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
}

struct MacroField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.text)
            HStack(spacing: 4) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(AppTextFieldStyle())
                Text("g")
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
            }
        }
    }
}

struct AdditionalActivityDraft: Identifiable {
    let id = UUID()
    var activityType = ""
    var duration = ""
}

struct AdditionalActivityCard: View {
    @Binding var activity: AdditionalActivityDraft
    let remove: () -> Void

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Additional activity (Optional)")
                        .font(.headline)
                        .foregroundStyle(AppColor.text)
                    Spacer()
                    Button(action: remove) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                ActivityTypeMenu(selection: $activity.activityType, placeholder: "Activity type (Optional)")
                FormField(title: "Duration (min) (Optional)", text: $activity.duration, placeholder: "Enter minutes")
            }
        }
    }
}

struct ActivityTypeMenu: View {
    @Binding var selection: String
    let placeholder: String
    private let options = [
        "Brisk walking",
        "Cycling",
        "Swimming",
        "Strength training",
        "Running",
        "Yoga or stretching",
        "Sports",
        "Other activity",
    ]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    selection = option
                }
            }
            Button("Clear") {
                selection = ""
            }
        } label: {
            HStack {
                Text(selection.isEmpty ? placeholder : selection)
                    .foregroundStyle(selection.isEmpty ? Color.gray : AppColor.ink)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(AppColor.ink)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
        }
        .buttonStyle(.plain)
    }
}

struct FoodJournalActionButton: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(AppColor.blue)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 76)
        .padding(.horizontal, 8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.blue))
    }
}

struct StepIndicator: View {
    let currentStep: Int
    let labels: [String]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(labels.indices, id: \.self) { index in
                    let number = index + 1
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(number <= currentStep ? AppColor.blue : .white)
                                .overlay(Circle().stroke(AppColor.line))
                                .frame(width: 28, height: 28)
                            Text("\(number)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(number <= currentStep ? .white : AppColor.muted)
                        }
                        Text(labels[index])
                            .font(.caption)
                            .foregroundStyle(number == currentStep ? AppColor.blue : AppColor.text)
                    }
                    if index < labels.count - 1 {
                        Rectangle()
                            .fill(number < currentStep ? AppColor.blue : AppColor.line)
                            .frame(height: 2)
                            .padding(.bottom, 22)
                    }
                }
            }
        }
    }
}

struct WeeklyMeasurementBadge: View {
    var body: some View {
        Label("Weekly measurement", systemImage: "calendar")
            .font(.caption.weight(.medium))
            .foregroundStyle(AppColor.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.10))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct YesNoCard: View {
    let title: String
    @Binding var value: Bool?

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text("Required")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Capsule())
                }
                HStack(spacing: 0) {
                    yesNoButton(title: "Yes", option: true)
                    yesNoButton(title: "No", option: false)
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
            }
        }
    }

    private func yesNoButton(title: String, option: Bool) -> some View {
        Button {
            value = option
        } label: {
            Text(title)
                .font(.headline)
                .foregroundStyle(value == option ? AppColor.blue : AppColor.text)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(value == option ? Color.blue.opacity(0.10) : .white)
        }
        .buttonStyle(.plain)
    }
}

struct AppleHealthRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SectionCard {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .frame(width: 42, height: 42)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
                    Text("Import from Apple Health")
                        .font(.headline)
                        .foregroundStyle(AppColor.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColor.text)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
