import Foundation

struct DailyInsightsRequest: Codable {
    let checkIn: DailyCheckIn

    enum CodingKeys: String, CodingKey {
        case checkIn = "check_in"
    }
}

struct DailyInsightAPIItem: Codable {
    let icon: String
    let title: String
    let whatWeNoticed: String
    let whyItMayMatter: String
    let nextStep: String

    enum CodingKeys: String, CodingKey {
        case icon
        case title
        case whatWeNoticed = "what_we_noticed"
        case whyItMayMatter = "why_it_may_matter"
        case nextStep = "next_step"
    }

    var dailyInsight: DailyInsight {
        DailyInsight(
            icon: icon,
            title: title,
            whatWeNoticed: whatWeNoticed,
            whyItMayMatter: whyItMayMatter,
            nextStep: nextStep
        )
    }
}

struct DailyInsightsResponse: Codable {
    let source: String
    let insights: [DailyInsightAPIItem]
    let disclaimer: String
}

struct DailyInsightsAPI {
    var baseURL = AppEnvironment.apiBaseURL
    var session: URLSession = .shared

    func generate(checkIn: DailyCheckIn) async throws -> DailyInsightsResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("insights/daily"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try JSONEncoder().encode(DailyInsightsRequest(checkIn: checkIn))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RiskPredictionAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RiskPredictionAPIError.serverMessage("Daily insights failed with status \(httpResponse.statusCode).")
        }
        return try JSONDecoder().decode(DailyInsightsResponse.self, from: data)
    }
}
