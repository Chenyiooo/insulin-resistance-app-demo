import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isShowingPrivacyNotice = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                CloudyMascotView(size: 190)
                    .padding(.top, 52)

                VStack(spacing: 16) {
                    Text("Welcome")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.black)
                    Text("Track, understand, and reflect on everyday habits related to insulin resistance.")
                        .font(.title3)
                        .foregroundStyle(AppColor.text)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                }

                Text("This app supports health awareness and healthier choices. It does not provide a medical diagnosis or replace professional medical advice.")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.27, green: 0.36, blue: 0.51))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(AppColor.sky)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15)))
                    .padding(.horizontal, 32)

                authControls
                    .padding(.horizontal, 32)
                    .padding(.bottom, 38)
            }
            .frame(maxWidth: .infinity)
        }
        .background(.white)
        .sheet(isPresented: $isShowingPrivacyNotice) {
            PrivacyNoticeView()
        }
    }

    private var authControls: some View {
        VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Email", text: $store.authEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(AppTextFieldStyle())
                    SecureField("Password", text: $store.authPassword)
                        .textFieldStyle(AppTextFieldStyle())
                    if !store.authMessage.isEmpty {
                        Text(store.authMessage)
                            .font(.caption)
                            .foregroundStyle(AppColor.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        store.hasAcceptedPrivacyTerms.toggle()
                        UserDefaults.standard.set(store.hasAcceptedPrivacyTerms, forKey: "hasAcceptedPrivacyTerms")
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: store.hasAcceptedPrivacyTerms ? "checkmark.square.fill" : "square")
                                .foregroundStyle(AppColor.blue)
                            Text("I understand this is not a medical diagnosis and agree to the privacy and safety notice.")
                                .font(.caption)
                                .foregroundStyle(AppColor.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    Button("Read Privacy & Safety Notice") {
                        isShowingPrivacyNotice = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.blue)
                }

                PrimaryButton(title: "Log In") {
                    store.logIn()
                }
                .disabled(store.isAuthenticating || !store.hasAcceptedPrivacyTerms)

                OutlineButton(title: "Create Account") {
                    store.createAccount()
                }
                .disabled(store.isAuthenticating || !store.hasAcceptedPrivacyTerms)

                Button("Continue without account") {
                    if store.hasAcceptedPrivacyTerms {
                        store.showMain()
                    } else {
                        store.authMessage = "Review and accept Privacy & Safety before continuing."
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColor.blue)
        }
    }
}
