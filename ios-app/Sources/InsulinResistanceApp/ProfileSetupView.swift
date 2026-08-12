import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var store: AppStore
    var isModalFlow = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                introCard
                questionFields
                PrimaryButton(title: isModalFlow ? "Continue" : "Save Profile") {
                    store.showMain(tab: .home)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(.white)
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

    private var introCard: some View {
        HStack(alignment: .center, spacing: 20) {
            CloudyMascotView(size: 128)
            VStack(alignment: .leading, spacing: 12) {
                Text("How we use your information")
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.ink)
                Label("Risk estimate: Your answers help us estimate your risk related to insulin resistance.", systemImage: "shield")
                Label("Personalized guidance: Some answers also help tailor suggestions to your needs.", systemImage: "person")
                Divider()
                Label("For screening and reflection only, not a medical diagnosis.", systemImage: "info.circle")
            }
            .font(.callout)
            .foregroundStyle(AppColor.ink)
        }
        .padding(18)
        .background(AppColor.sky)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var questionFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            FormField(title: "1. What is your age?", text: $store.profile.age, placeholder: "Enter your age")

            VStack(alignment: .leading, spacing: 8) {
                Text("2. What sex were you assigned at birth?")
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                Menu {
                    Button("Female") { store.profile.sexAtBirth = "Female" }
                    Button("Male") { store.profile.sexAtBirth = "Male" }
                    Button("Prefer not to answer") { store.profile.sexAtBirth = "Prefer not to answer" }
                } label: {
                    SelectLikeField(value: store.profile.sexAtBirth)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("3. Have you ever been pregnant?")
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                Picker("Pregnancy", selection: $store.profile.hasBeenPregnant) {
                    Text("Yes").tag(true)
                    Text("No").tag(false)
                }
                .pickerStyle(.segmented)
            }

            if store.profile.hasBeenPregnant {
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("During any of your pregnancies, were you ever diagnosed with gestational diabetes?")
                            .font(.headline)
                            .foregroundStyle(AppColor.ink)
                        ForEach(["Yes", "No", "Not applicable", "Prefer not to answer"], id: \.self) { option in
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
                Text("5. What is your race or ethnicity? (Select all that apply)")
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                SelectLikeField(value: store.profile.raceEthnicity.joined(separator: ", "))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("6. What is your height?")
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
