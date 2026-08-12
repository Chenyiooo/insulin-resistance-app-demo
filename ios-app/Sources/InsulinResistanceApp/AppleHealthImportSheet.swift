import SwiftUI

struct AppleHealthImportSheet: View {
    let useData: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Capsule()
                .fill(AppColor.line)
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Label("Apple Health", systemImage: "heart.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.red)
                Text("Review imported data")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColor.text)
                Text("Prototype mode uses sample Apple Health data. The real app will request HealthKit permission and read supported data from the device.")
                    .font(.callout)
                    .foregroundStyle(AppColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ImportedHealthRow(icon: "moon.zzz", title: "Sleep", value: "7.2 hr")
                Divider()
                ImportedHealthRow(icon: "figure.walk", title: "Brisk walking", value: "25 min")
                Divider()
                ImportedHealthRow(icon: "heart.text.square", title: "Blood pressure", value: "118/76")
                Divider()
                ImportedHealthRow(icon: "scalemass", title: "Weight", value: "146 lb")
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColor.line))

            Spacer()

            PrimaryButton(title: "Use these data") {
                useData()
            }
        }
        .padding(22)
        .background(Color(red: 0.98, green: 0.99, blue: 1.0))
    }
}

struct ImportedHealthRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppColor.blue)
                .frame(width: 38, height: 38)
                .background(Color.blue.opacity(0.08))
                .clipShape(Circle())
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.text)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(AppColor.muted)
        }
        .padding(14)
    }
}
