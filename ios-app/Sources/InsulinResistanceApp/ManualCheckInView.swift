import SwiftUI

struct ManualCheckInView: View {
    @EnvironmentObject private var store: AppStore
    @State private var step = 1
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    StepIndicator(currentStep: step, labels: ["Body", "Habits", "Activity", "Reflection"])
                    InfoBanner()

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
                                store.completeCheckIn()
                            } else {
                                step += 1
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            BottomTabBar()
        }
        .background(.white)
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

    private var bodyStep: some View {
        VStack(spacing: 14) {
            SmallScheduleBadge()
            SectionCard {
                FormField(title: "Weight (lb)", text: $store.checkIn.weight, placeholder: "Enter weight")
            }
            SectionCard {
                FormField(title: "Waist circumference (in)", text: $store.checkIn.waist, placeholder: "Enter waist")
            }
            SectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blood pressure (mmHg)")
                        .font(.headline)
                    HStack {
                        TextField("e.g., 120", text: $store.checkIn.systolic)
                            .textFieldStyle(AppTextFieldStyle())
                        Text("/")
                            .font(.title2)
                        TextField("e.g., 80", text: $store.checkIn.diastolic)
                            .textFieldStyle(AppTextFieldStyle())
                    }
                }
            }
            AppleHealthRow()
        }
    }

    private var habitsStep: some View {
        VStack(spacing: 14) {
            YesNoCard(title: "Did you smoke today?", value: $store.checkIn.smokedToday)
            YesNoCard(title: "Did you drink alcohol today?", value: $store.checkIn.drankAlcoholToday)
            SectionCard {
                FormField(title: "How many hours did you sleep last night?", text: $store.checkIn.sleepHours, placeholder: "Enter hours")
            }
            AppleHealthRow()
        }
    }

    private var activityStep: some View {
        VStack(spacing: 14) {
            YesNoCard(title: "Were you physically active today?", value: $store.checkIn.activeToday)
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
            AppleHealthRow()
            Button {
            } label: {
                Text("+ Add another activity")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.blue, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
        }
    }

    private var reflectionStep: some View {
        VStack(spacing: 14) {
            SectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("During periods of sitting, how often did you take a 2-3 minute movement break today?")
                        .font(.headline)
                    SelectLikeField(value: store.checkIn.movementBreaks)
                }
            }
            SectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Would you like to record what you ate and drank today?")
                            .font(.headline)
                        Spacer()
                        Text("Optional")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                    HStack(spacing: 12) {
                        OutlineButton(title: "Upload photos") {}
                        OutlineButton(title: "Describe") {
                            store.checkIn.foodJournal = "Added"
                        }
                    }
                    Button("Skip for now") {
                        store.checkIn.foodJournal = "Skipped"
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity)
                }
            }
            AppleHealthRow()
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

struct SmallScheduleBadge: View {
    var body: some View {
        Label("Weekly · Saturdays", systemImage: "calendar")
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
    var body: some View {
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
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColor.text)
            }
        }
    }
}
