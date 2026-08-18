import Foundation

enum AppEnvironment {
    private static let fallbackAPIBaseURLString = "http://127.0.0.1:8000"

    static var apiBaseURL: URL {
        let configuredValue = Bundle.main.object(forInfoDictionaryKey: "IRAPIBaseURL") as? String
        let value = configuredValue?.isEmpty == false ? configuredValue! : fallbackAPIBaseURLString
        return URL(string: value) ?? URL(string: fallbackAPIBaseURLString)!
    }
}

struct RiskPredictionResponse: Codable {
    let modelName: String
    let modelVersion: String
    let probability: Double
    let percent: Int
    let band: String
    let threshold: Double
    let featuresUsed: [String]
    let imputedFeatures: [String]
    let increasingFactors: [String]
    let decreasingFactors: [String]
    let suggestions: [RiskSuggestionResponse]
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case modelVersion = "model_version"
        case probability
        case percent
        case band
        case threshold
        case featuresUsed = "features_used"
        case imputedFeatures = "imputed_features"
        case increasingFactors = "increasing_factors"
        case decreasingFactors = "decreasing_factors"
        case suggestions
        case disclaimer
    }
}

struct RiskSuggestionResponse: Codable {
    let domain: String
    let title: String
    let text: String
    let triggerReason: String
    let safetyNote: String
    let confidence: String

    enum CodingKeys: String, CodingKey {
        case domain
        case title
        case text
        case triggerReason = "trigger_reason"
        case safetyNote = "safety_note"
        case confidence
    }
}

enum RiskPredictionAPIError: Error, LocalizedError {
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The prediction server returned an invalid response."
        case .serverMessage(let message):
            return message
        }
    }
}

struct RiskPredictionAPI {
    var baseURL = AppEnvironment.apiBaseURL
    var session: URLSession = .shared

    func predict(payload: ModelInputPayload) async throws -> RiskPredictionResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("predict"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RiskPredictionAPIError.invalidResponse
        }

        if (200..<300).contains(httpResponse.statusCode) {
            return try JSONDecoder().decode(RiskPredictionResponse.self, from: data)
        }

        if let serverError = try? JSONDecoder().decode(RiskPredictionServerError.self, from: data) {
            throw RiskPredictionAPIError.serverMessage(serverError.readableMessage)
        }

        throw RiskPredictionAPIError.serverMessage("Prediction failed with status \(httpResponse.statusCode).")
    }
}

private struct RiskPredictionServerError: Codable {
    let detail: RiskPredictionServerErrorDetail?

    var readableMessage: String {
        detail?.message ?? "The prediction server could not process this request."
    }
}

private struct RiskPredictionServerErrorDetail: Codable {
    let message: String?
    let missingFeatures: [String]?

    enum CodingKeys: String, CodingKey {
        case message
        case missingFeatures = "missing_features"
    }
}
