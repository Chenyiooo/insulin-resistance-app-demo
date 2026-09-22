import Foundation

struct LocalNutritionEstimator {
    static func estimate(text: String, imageCount: Int) -> NutritionEstimateResponse {
        let hasFoodInput = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageCount > 0
        return NutritionEstimateResponse(
            calories: 0,
            carbohydrates: 0,
            protein: 0,
            fat: 0,
            matchedFoods: [],
            source: "unable_to_estimate",
            confidence: "low",
            explanation: hasFoodInput
                ? "Nutrition could not be estimated from the bundled USDA food data."
                : "Add a food description or photo first.",
            disclaimer: "Nutrition values are estimates for reflection only, not medical or dietary advice."
        )
    }
}
