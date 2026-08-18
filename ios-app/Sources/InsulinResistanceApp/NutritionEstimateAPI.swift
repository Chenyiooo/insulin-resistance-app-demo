import Foundation

struct NutritionEstimateRequest: Codable {
    var text: String
    var imageBase64: [String]

    enum CodingKeys: String, CodingKey {
        case text
        case imageBase64 = "image_base64"
    }
}

struct NutritionEstimateResponse: Codable {
    let calories: Int
    let carbohydrates: Double
    let protein: Double
    let fat: Double
    let matchedFoods: [String]
    let source: String
    let confidence: String
    let explanation: String
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case calories
        case carbohydrates
        case protein
        case fat
        case matchedFoods = "matched_foods"
        case source
        case confidence
        case explanation
        case disclaimer
    }
}

struct NutritionEstimateAPI {
    var baseURL = AppEnvironment.apiBaseURL
    var session: URLSession = .shared

    func estimate(text: String, imageBase64: [String]) async throws -> NutritionEstimateResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("nutrition/estimate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8
        request.httpBody = try JSONEncoder().encode(
            NutritionEstimateRequest(text: text, imageBase64: imageBase64)
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RiskPredictionAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RiskPredictionAPIError.serverMessage("Nutrition estimate failed with status \(httpResponse.statusCode).")
        }
        return try JSONDecoder().decode(NutritionEstimateResponse.self, from: data)
    }
}
