import SwiftUI

struct PrivacyNoticeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    noticeSection(
                        title: "Medical disclaimer",
                        icon: "cross.case",
                        lines: [
                            "This app provides a screening estimate and wellness reflection support only.",
                            "It does not diagnose insulin resistance, diabetes, or any medical condition.",
                            "Do not use this app for emergencies or treatment decisions. Contact a qualified clinician for medical advice.",
                        ]
                    )

                    noticeSection(
                        title: "Data we collect",
                        icon: "lock.doc",
                        lines: [
                            "Profile information such as age, sex assigned at birth, race or ethnicity, height, and selected health-history answers.",
                            "Check-in information such as weight, waist, optional blood pressure, sleep, activity, movement breaks, food journal status, and reflections.",
                            "Optional Apple Health data only after you grant Apple Health permission.",
                        ]
                    )

                    noticeSection(
                        title: "How data is used",
                        icon: "waveform.path.ecg",
                        lines: [
                            "Your data is used to save your app progress, sync signed-in accounts, fill check-ins, estimate screening risk, and generate non-diagnostic insights.",
                            "The reduced LightGBM model uses 18 mapped features. Food photos and free-text reflections are not model predictors in the current version.",
                        ]
                    )

                    noticeSection(
                        title: "Security choices in this prototype",
                        icon: "shield",
                        lines: [
                            "Your login token is stored in the iOS Keychain.",
                            "The development backend stores account data in a local SQLite database. Deployments should use HTTPS, a managed database, backup policies, and server-side secret management.",
                            "You can sign out from Profile. Account deletion is supported by the backend API.",
                        ]
                    )

                    Button {
                        store.acceptPrivacyTerms()
                        dismiss()
                    } label: {
                        Text("I understand and agree")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppColor.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("Privacy & Safety")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func noticeSection(title: String, icon: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(AppColor.ink)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(AppColor.blue)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(line)
                            .font(.callout)
                            .foregroundStyle(AppColor.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColor.sky)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
