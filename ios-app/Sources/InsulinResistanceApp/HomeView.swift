import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var knowledgeItem = InsulinKnowledgeLibrary.randomItem()
    private var greetingName: String {
        let trimmedName = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "there" : trimmedName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Good evening, \(greetingName)!")
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
                        Text(knowledgeItem.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppColor.ink)
                        Text(knowledgeItem.body)
                            .font(.title3)
                            .foregroundStyle(AppColor.text)
                            .lineSpacing(5)
                        HStack {
                            Text("Source: \(knowledgeItem.source)")
                                .foregroundStyle(AppColor.muted)
                            Spacer()
                            Link("Learn more", destination: knowledgeItem.url)
                                .foregroundStyle(AppColor.blue)
                        }
                        .font(.title3)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            knowledgeItem = InsulinKnowledgeLibrary.randomItem(excluding: knowledgeItem)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }
}

struct InsulinKnowledgeItem: Equatable {
    let title: String
    let body: String
    let source: String
    let url: URL
}

enum InsulinKnowledgeLibrary {
    static let items: [InsulinKnowledgeItem] = [
        InsulinKnowledgeItem(
            title: "What is insulin resistance?",
            body: "Insulin resistance means the body's cells do not respond to insulin as well as expected. Over time, the pancreas may need to make more insulin to help glucose enter cells.",
            source: "NIDDK",
            url: URL(string: "https://www.niddk.nih.gov/health-information/diabetes/overview/what-is-diabetes/prediabetes-insulin-resistance")!
        ),
        InsulinKnowledgeItem(
            title: "Prediabetes often has no clear symptoms",
            body: "Many people with insulin resistance or prediabetes do not notice symptoms. Screening and routine health visits matter because blood glucose can change before someone feels different.",
            source: "NIDDK",
            url: URL(string: "https://www.niddk.nih.gov/health-information/diabetes/overview/what-is-diabetes/prediabetes-insulin-resistance")!
        ),
        InsulinKnowledgeItem(
            title: "Small lifestyle changes can matter",
            body: "The CDC's National Diabetes Prevention Program is based on lifestyle changes such as healthier eating, more physical activity, and modest weight loss for people at high risk.",
            source: "CDC National DPP",
            url: URL(string: "https://www.cdc.gov/diabetes-prevention/programs/what-is-the-national-dpp.html")!
        ),
        InsulinKnowledgeItem(
            title: "Physical activity supports glucose regulation",
            body: "Regular physical activity can help the body use glucose and manage blood sugar. Starting small, such as a short walk after dinner, can still be useful.",
            source: "CDC",
            url: URL(string: "https://www.cdc.gov/diabetes/living-with/physical-activity.html")!
        ),
        InsulinKnowledgeItem(
            title: "Sitting breaks are part of the picture",
            body: "Diabetes care guidance encourages reducing prolonged sitting. Short standing or walking breaks can be a practical way to interrupt long sedentary periods.",
            source: "ADA Standards of Care",
            url: URL(string: "https://doi.org/10.2337/dc23-S005")!
        ),
        InsulinKnowledgeItem(
            title: "Sleep and insulin sensitivity are connected",
            body: "Research reviews have found that restricted sleep can reduce insulin sensitivity. Sleep is not a diagnosis, but it is useful context for metabolic health reflection.",
            source: "Sleep Medicine Reviews / PubMed",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/35189549/")!
        ),
        InsulinKnowledgeItem(
            title: "Risk estimates are not diagnoses",
            body: "Health professionals use blood tests to diagnose prediabetes or diabetes. App-based estimates should be used for reflection and discussion, not as medical conclusions.",
            source: "NIDDK",
            url: URL(string: "https://www.niddk.nih.gov/health-information/diabetes/overview/what-is-diabetes/prediabetes-insulin-resistance")!
        ),
    ]

    static func randomItem(excluding current: InsulinKnowledgeItem? = nil) -> InsulinKnowledgeItem {
        let candidates = items.filter { $0 != current }
        return candidates.randomElement() ?? items[0]
    }
}
