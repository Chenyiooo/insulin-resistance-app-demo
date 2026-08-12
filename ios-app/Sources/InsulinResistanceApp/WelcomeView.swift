import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 54)

            CloudyMascotView(size: 220)

            VStack(spacing: 16) {
                Text("Welcome")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.black)
                Text("Track, understand, and reflect on everyday habits related to insulin resistance.")
                    .font(.title3)
                    .foregroundStyle(AppColor.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 20)
            }

            Text("This app supports health awareness and healthier choices. It does not provide a medical diagnosis or replace professional medical advice.")
                .font(.title3)
                .foregroundStyle(Color(red: 0.27, green: 0.36, blue: 0.51))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(24)
                .background(AppColor.sky)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.15)))
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 18) {
                PrimaryButton(title: "Log In") {
                    store.showMain()
                }
                OutlineButton(title: "Create Profile") {
                    store.screen = .profile
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 38)
        }
        .background(.white)
    }
}
