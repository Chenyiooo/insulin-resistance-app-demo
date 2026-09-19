import SwiftUI

struct WelcomeView: View {
    private enum AuthMode {
        case logIn
        case createAccount
    }

    @EnvironmentObject private var store: AppStore
    @State private var isShowingPrivacyNotice = false
    @State private var authMode: AuthMode = .logIn

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                CloudyMascotView(size: 190)
                    .padding(.top, 52)

                VStack(spacing: 16) {
                    Text(authMode == .logIn ? "Welcome Back" : "Create Account")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.black)
                    Text(authMode == .logIn
                         ? "Log in to continue tracking and understanding your everyday habits."
                         : "Create an account to securely save your profile and daily check-ins.")
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
                    if authMode == .createAccount {
                        TextField("Name", text: $store.authName)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(AppTextFieldStyle())
                    }
                    TextField("Email", text: $store.authEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textFieldStyle(AppTextFieldStyle())
                    SecureField("Password", text: $store.authPassword)
                        .textContentType(authMode == .createAccount ? .newPassword : .password)
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

                PrimaryButton(title: authMode == .logIn ? "Log In" : "Create Account") {
                    if authMode == .logIn {
                        store.logIn()
                    } else {
                        store.createAccount()
                    }
                }
                .disabled(store.isAuthenticating || !store.hasAcceptedPrivacyTerms)

                OutlineButton(title: authMode == .logIn ? "Create Account" : "Back to Log In") {
                    store.authMessage = ""
                    authMode = authMode == .logIn ? .createAccount : .logIn
                }
                .disabled(store.isAuthenticating)
        }
    }
}
