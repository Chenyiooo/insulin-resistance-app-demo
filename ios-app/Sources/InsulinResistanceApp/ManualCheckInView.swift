import SwiftUI
import SwiftData

struct ManualCheckInView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @State private var step = 1
    @State private var isShowingHealthImport = false
    @State private var missingItems: [MissingDataItem] = []
    @State private var isShowingMissingDataWarning = false
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    StepIndicator(currentStep: step, labels: ["Weekly", "Sleep", "Activity", "Reflection"])
                    stageIntro

                    Group {
                        switch step {
                        case 1: bodyStep
                        case 2: habitsStep
                        case 3: activityStep
                        default: reflectionStep
                        }
                    }

                    HStack {
                        CloudyMascotView(size: 104)
                        Spacer()
                        Button {
                            store.screen = .aiCheckIn
                        } label: {
                            Text("Switch to AI input")
                                .font(.footnote.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 14) {
                        if step > 1 {
                            OutlineButton(title: "Back") {
                                step -= 1
                            }
                        }
                        PrimaryButton(title: step == totalSteps ? "Review check-in" : "Continue") {
                            if step == totalSteps {
                                completeWithValidation()
                            } else {
                                store.saveCheckIn(in: modelContext)
                                step += 1
                            }
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
        .alert("Check-in saved with missing data", isPresented: $isShowingMissingDataWarning) {
            Button("Complete Anyway") {
                store.screen = .completion
            }
            Button("Review", role: .cancel) {}
        } message: {
            Text(missingDataMessage)
        }
    }

    private var missingDataMessage: String {
        if missingItems.isEmpty { return "" }
        let labels = missingItems.map { "\($0.label): \($0.code)" }.joined(separator: "\n")
        return "We need a little more information before we can update your risk estimate.\n\n\(labels)"
    }

    private func completeWithValidation() {
        store.checkIn.isCompleted = true
        missingItems = store.checkInMissingDataItems()
        store.saveCheckIn(in: modelContext)
        if missingItems.isEmpty {
            store.screen = .completion
        } else {
            isShowingMissingDataWarning = true
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

    private var stageIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            if step == 1 {
                Text("These weekly measurements help us update your estimated risk related to insulin resistance and show changes over time.")
            } else {
                Text("Required questions are marked with an asterisk (*). Your answers help us summarize your day and provide relevant lifestyle suggestions. You can still complete the check-in if you skip optional questions.")
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
                    Text("Please enter your current weight if you are able to measure it today.")
                        .font(.callout)
                        .foregroundStyle(AppColor.text)
                    FormField(title: "Weight", text: $store.checkIn.weight, placeholder: "Enter weight")
                    Picker("Weight unit", selection: $store.checkIn.weightUnit) {
                        Text("lb").tag("lb")
                        Text("kg").tag("kg")
                    }
                    .pickerStyle(.segmented)
                }
            }
            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    FormField(title: "Waist circumference", text: $store.checkIn.waist, placeholder: "Enter waist")
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
            AppleHealthRow {
                isShowingHealthImport = true
            }
        }
    }

    private var habitsStep: some View {
        VStack(spacing: 14) {
            SectionCard {
                FormField(title: "About how many hours did you sleep last night? *", text: $store.checkIn.sleepHours, placeholder: "Enter hours")
            }
            AppleHealthRow {
                isShowingHealthImport = true
            }
        }
    }

    private var activityStep: some View {
        VStack(spacing: 14) {
            YesNoCard(title: "Were you physically active today?", value: $store.checkIn.activeToday)
            if store.checkIn.activeToday == true {
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tell us about your activity")
                            .font(.headline)
                        SelectLikeField(value: store.checkIn.activityType)
                        FormField(title: "Duration (min)", text: $store.checkIn.activityDuration, placeholder: "Enter minutes")
                        Text("e.g., brisk walking, cycling, swimming, strength training")
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                    }
                }
                AppleHealthRow {
                    isShowingHealthImport = true
                }
                Button {
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
            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Would you like to add a food journal for today? (Optional)")
                        .font(.headline)
                    Text("Upload photos or briefly describe what you ate and drank. You can use both methods and add anything that is not shown in your photos.")
                        .font(.callout)
                        .foregroundStyle(AppColor.muted)
                    HStack(spacing: 12) {
                        OutlineButton(title: "Upload Photos") {}
                        OutlineButton(title: "Describe What I Ate and Drank") {
                            store.checkIn.foodJournal = "Added"
                        }
                    }
                    Button("Skip for Now") {
                        store.checkIn.foodJournal = "Skipped"
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity)
                }
            }
            SectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("After entering today's data, what did you notice about how your routines, behaviors, or body may be related to your metabolic health or insulin resistance risk today?")
                        .font(.headline)
                    Text("Optional prompts: What stood out to you today? Did anything surprise you? Did you notice any connection among your activity, movement breaks, sleep, food, stress, energy, or symptoms?")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                    TextEditor(text: $store.checkIn.dailyReflection)
                        .frame(minHeight: 110)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
                }
            }
            AppleHealthRow {
                isShowingHealthImport = true
            }
        }
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
                Picker(title, selection: Binding(
                    get: { value ?? true },
                    set: { value = $0 }
                )) {
                    Text("Yes").tag(true)
                    Text("No").tag(false)
                }
                .pickerStyle(.segmented)
            }
        }
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
