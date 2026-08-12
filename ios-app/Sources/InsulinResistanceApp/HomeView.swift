import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Good evening, \(store.profile.name)!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppColor.ink)
                        Text("Small check-ins can help you notice patterns over time.")
                            .font(.title3)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                    }
                    Spacer()
                    CloudyMascotView(size: 120)
                }
                .padding(.top, 36)

                SectionCard {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Today's Check-in")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppColor.ink)
                        Text("Log today's sleep, activity, movement breaks, and optional food journal.")
                            .font(.title3)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                        PrimaryButton(title: "Start Check-in") {
                            store.startCheckIn()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(AppColor.sky)

                SectionCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("LEARN ABOUT INSULIN RESISTANCE")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColor.blue)
                        Text("What is insulin resistance?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppColor.ink)
                        Text("Insulin resistance happens when the body does not respond to insulin as well as it should. Over time, this may lead to higher blood sugar levels.")
                            .font(.title3)
                            .foregroundStyle(AppColor.text)
                            .lineSpacing(5)
                        HStack {
                            Text("Source: NIDDK")
                                .foregroundStyle(AppColor.muted)
                            Spacer()
                            Text("Learn more")
                                .foregroundStyle(AppColor.blue)
                        }
                        .font(.title3)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(.white)
    }
}

struct CloudyHomeView: View {
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            CloudyMascotView(size: 210)
            Text("Cloudy")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.ink)
            Text("Your check-in companion is ready when you are.")
                .font(.title3)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(28)
    }
}
