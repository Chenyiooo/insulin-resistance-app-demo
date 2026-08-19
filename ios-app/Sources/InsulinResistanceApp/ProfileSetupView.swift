import SwiftUI
import SwiftData

struct ProfileSetupView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @State private var missingItems: [MissingDataItem] = []
    @State private var isShowingMissingDataWarning = false
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var isShowingPrivacyNotice = false
    var isModalFlow = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                accountStatus
                introCard
                questionFields
                PrimaryButton(title: isModalFlow ? "Continue" : "Save Profile") {
                    saveProfileWithValidation()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .alert("Required profile answer missing", isPresented: $isShowingMissingDataWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(missingDataMessage)
        }
        .confirmationDialog("Delete account and cloud data?", isPresented: $isShowingDeleteAccountConfirmation, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                store.deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your account, cloud profile, cloud check-ins, and active sessions from the backend development database.")
        }
        .sheet(isPresented: $isShowingPrivacyNotice) {
            PrivacyNoticeView()
        }
    }

    private var missingDataMessage: String {
        if missingItems.isEmpty { return "" }
        let labels = missingItems.map { "\($0.label): \($0.code)" }.joined(separator: "\n")
        return "Please answer the required profile question\(missingItems.count == 1 ? "" : "s") before continuing.\n\n\(labels)"
    }

    private func saveProfileWithValidation() {
        missingItems = store.profileMissingDataItems()
        if missingItems.isEmpty {
            store.saveProfile(in: modelContext)
            store.showMain(tab: .home)
        } else {
            isShowingMissingDataWarning = true
        }
    }

    private var header: some View {
        HStack {
            Button {
                store.screen = isModalFlow ? .welcome : .main
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColor.ink)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Profile")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColor.ink)
            Spacer()
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.top, 22)
    }

    private var accountStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: store.isSignedIn ? "icloud.fill" : "icloud.slash")
                .foregroundStyle(store.isSignedIn ? AppColor.blue : AppColor.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.isSignedIn ? "Signed in: \(store.accountEmail)" : "Not signed in")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.text)
                if !store.cloudSyncMessage.isEmpty {
                    Text(store.cloudSyncMessage)
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }
            Spacer()
            if store.isSignedIn {
                Menu {
                    Button("Privacy & Safety") {
                        isShowingPrivacyNotice = true
                    }
                    Button("Export my data") {
                        store.exportAccountData()
                    }
                    Button("Sign out") {
                        store.signOut()
                    }
                    Button("Delete account", role: .destructive) {
                        isShowingDeleteAccountConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(AppColor.blue)
                }
            }
        }
        .padding(12)
        .background(AppColor.sky)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 20) {
                CloudyMascotView(size: 112)
                VStack(alignment: .leading, spacing: 10) {
                    Text("How we use your information")
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.ink)
                    Label("Risk estimate: Your answers help us estimate your risk related to insulin resistance.", systemImage: "shield")
                    Label("Personalized guidance: Some answers also help tailor suggestions to your needs.", systemImage: "person")
                }
                .font(.callout)
                .foregroundStyle(AppColor.ink)
            }
            Divider()
            Text("Required questions are marked with an asterisk (*). The initial profile must be completed before the app can generate periodic estimates related to insulin resistance.")
                .font(.callout)
                .foregroundStyle(AppColor.text)
                .fixedSize(horizontal: false, vertical: true)
            Label("For screening and reflection only, not a medical diagnosis.", systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(AppColor.ink)
        }
        .padding(18)
        .background(AppColor.sky)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var questionFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            FormField(title: "1. What's your name? *", text: $store.profile.name, placeholder: "Enter your name")

            FormField(title: "2. What is your age? *", text: $store.profile.age, placeholder: "Enter your age")

            VStack(alignment: .leading, spacing: 8) {
                Text("3. What sex were you assigned at birth? *")
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                Menu {
                    Button("Female") { store.profile.sexAtBirth = "Female" }
                    Button("Male") { store.profile.sexAtBirth = "Male" }
                    Button("Intersex") { store.profile.sexAtBirth = "Intersex" }
                    Button("Prefer not to answer") { store.profile.sexAtBirth = "Prefer not to answer" }
                } label: {
                    SelectLikeField(value: store.profile.sexAtBirth)
                }
                if store.profile.sexAtBirth == "Prefer not to answer" {
                    Text("Choosing Prefer not to answer may prevent the app from generating a complete risk estimate.")
                        .font(.caption)
                        .foregroundStyle(AppColor.muted)
                }
            }

            if store.profile.sexAtBirth == "Female" {
                VStack(alignment: .leading, spacing: 10) {
                    Text("4. Have you ever been pregnant? *")
                        .font(.headline)
                        .foregroundStyle(AppColor.ink)
                    OptionGrid(options: ["Yes", "No", "Prefer not to answer"], selection: $store.profile.hasBeenPregnant)
                }
            }

            if store.profile.sexAtBirth == "Female" && store.profile.hasBeenPregnant == "Yes" {
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("During any of your pregnancies, were you ever diagnosed with gestational diabetes? *")
                            .font(.headline)
                            .foregroundStyle(AppColor.ink)
                        ForEach(["Yes", "No", "Not sure", "Prefer not to answer"], id: \.self) { option in
                            Button {
                                store.profile.gestationalDiabetes = option
                            } label: {
                                HStack {
                                    Image(systemName: store.profile.gestationalDiabetes == option ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(AppColor.blue)
                                    Text(option)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            if option != "Prefer not to answer" {
                                Divider()
                            }
                        }
                    }
                }
                .background(AppColor.sky)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("5. How would you describe your race and/or ethnicity? Select all that apply. *")
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                MultiSelectOptions(
                    options: ["Mexican American", "Other Hispanic", "Non-Hispanic White", "Non-Hispanic Black", "Non-Hispanic Asian", "Another race or ethnicity", "Prefer not to answer"],
                    selections: $store.profile.raceEthnicity
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("6. What is your height? *")
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                HStack {
                    TextField("Feet", text: $store.profile.heightFeet)
                        .textFieldStyle(AppTextFieldStyle())
                    Text("ft")
                    TextField("Inches", text: $store.profile.heightInches)
                        .textFieldStyle(AppTextFieldStyle())
                    Text("in")
                }
            }

            SingleSelectQuestion(
                title: "7. Have any of your close biological relatives, such as a biological parent or sibling, been diagnosed with diabetes? *",
                options: ["Yes", "No", "Not sure", "Prefer not to answer"],
                selection: $store.profile.familyHistoryDiabetes
            )

            SingleSelectQuestion(
                title: "8. Have you ever been told by a health professional that you have high blood pressure? *",
                options: ["Yes", "No", "Not sure", "Prefer not to answer"],
                selection: $store.profile.hypertensionHistory
            )

            SingleSelectQuestion(
                title: "9. Are you currently taking medication prescribed for high blood pressure? *",
                options: ["Yes", "No", "Not sure", "Prefer not to answer"],
                selection: $store.profile.antihypertensiveMedication
            )

            SingleSelectQuestion(
                title: "10. Have you ever been told by a health professional that you have high cholesterol? *",
                options: ["Yes", "No", "Not sure", "Prefer not to answer"],
                selection: $store.profile.highCholesterol
            )

            SingleSelectQuestion(
                title: "11. Which best describes your current smoking status? *",
                options: ["Never smoked", "Formerly smoked", "Currently smoke some days", "Currently smoke every day", "Prefer not to answer"],
                selection: $store.profile.smokingStatus
            )

            SingleSelectQuestion(
                title: "12. During the past 12 months, how often did you usually drink alcohol? *",
                options: ["Never in the past 12 months", "Monthly or less", "2-4 times a month", "2-3 times a week", "4 or more times a week", "Prefer not to answer"],
                selection: $store.profile.alcoholFrequency
            )
        }
    }
}

struct SingleSelectQuestion: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.ink)
            OptionGrid(options: options, selection: $selection)
        }
    }
}

struct OptionGrid: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(option)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(selection == option ? .white : AppColor.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                        .padding(.horizontal, 8)
                        .background(selection == option ? AppColor.blue : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection == option ? AppColor.blue : AppColor.line))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MultiSelectOptions: View {
    let options: [String]
    @Binding var selections: [String]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    if option == "Prefer not to answer" {
                        selections = [option]
                    } else if selections.contains(option) {
                        selections.removeAll { $0 == option }
                    } else {
                        selections.removeAll { $0 == "Prefer not to answer" }
                        selections.append(option)
                    }
                } label: {
                    HStack {
                        Image(systemName: selections.contains(option) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(AppColor.blue)
                        Text(option)
                            .foregroundStyle(AppColor.text)
                        Spacer()
                    }
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.ink)
            TextField(placeholder, text: $text)
                .textFieldStyle(AppTextFieldStyle())
        }
    }
}

struct SelectLikeField: View {
    let value: String

    var body: some View {
        HStack {
            Text(value.isEmpty ? "Select" : value)
                .foregroundStyle(value.isEmpty ? Color.gray : AppColor.ink)
            Spacer()
            Image(systemName: "chevron.down")
                .foregroundStyle(AppColor.ink)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
    }
}

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .frame(height: 54)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
    }
}
