import SwiftUI

enum AppColor {
    static let blue = Color(red: 0.02, green: 0.43, blue: 0.93)
    static let sky = Color(red: 0.92, green: 0.97, blue: 1.0)
    static let ink = Color(red: 0.02, green: 0.07, blue: 0.22)
    static let text = Color(red: 0.18, green: 0.19, blue: 0.24)
    static let muted = Color(red: 0.42, green: 0.43, blue: 0.48)
    static let line = Color(red: 0.86, green: 0.88, blue: 0.92)
    static let softBlue = Color(red: 0.94, green: 0.98, blue: 1.0)
    static let softViolet = Color(red: 0.96, green: 0.95, blue: 1.0)
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AppColor.blue)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct OutlineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColor.blue, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColor.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

struct InfoBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppColor.blue)
            Text("Your answers help estimate risk related to insulin resistance. This is a screening estimate, not a diagnosis.")
                .font(.footnote)
                .foregroundStyle(AppColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text("Why we ask")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColor.blue)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColor.blue)
        }
        .padding(14)
        .background(AppColor.sky)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CloudyMascotView: View {
    var size: CGFloat = 150

    var body: some View {
        Image("CloudyMascot")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size * 0.68)
            .allowsHitTesting(false)
            .accessibilityLabel("Cloudy")
    }
}
