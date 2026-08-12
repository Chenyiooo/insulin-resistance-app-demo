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
        ZStack {
            CloudShape()
                .fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 1)
                .overlay(CloudShape().stroke(Color.black.opacity(0.65), lineWidth: 2))
            CloudShape()
                .stroke(Color.blue.opacity(0.22), style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [8, 10]))
                .padding(8)
            Circle()
                .fill(.black)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: -size * 0.18, y: -size * 0.02)
            Circle()
                .fill(.black)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: size * 0.18, y: -size * 0.04)
            Path { path in
                path.move(to: CGPoint(x: size * 0.15, y: size * 0.58))
                path.addLine(to: CGPoint(x: size * 0.32, y: size * 0.60))
                path.addQuadCurve(to: CGPoint(x: size * 0.39, y: size * 0.57), control: CGPoint(x: size * 0.35, y: size * 0.56))
            }
            .stroke(.black, lineWidth: 3)
            .offset(x: -size * 0.30, y: size * 0.11)
            Circle()
                .fill(.black)
                .frame(width: size * 0.09, height: size * 0.06)
                .offset(x: -size * 0.29, y: size * 0.18)
        }
        .frame(width: size, height: size * 0.68)
    }
}

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.08, y: h * 0.68))
        path.addQuadCurve(to: CGPoint(x: w * 0.23, y: h * 0.34), control: CGPoint(x: w * 0.08, y: h * 0.45))
        path.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.22), control: CGPoint(x: w * 0.32, y: h * 0.13))
        path.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.10), control: CGPoint(x: w * 0.48, y: h * 0.00))
        path.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.36), control: CGPoint(x: w * 0.78, y: h * 0.08))
        path.addQuadCurve(to: CGPoint(x: w * 0.94, y: h * 0.56), control: CGPoint(x: w * 0.96, y: h * 0.38))
        path.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.76), control: CGPoint(x: w * 0.93, y: h * 0.78))
        path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.76))
        path.addQuadCurve(to: CGPoint(x: w * 0.08, y: h * 0.68), control: CGPoint(x: w * 0.08, y: h * 0.76))
        path.closeSubpath()
        return path
    }
}
