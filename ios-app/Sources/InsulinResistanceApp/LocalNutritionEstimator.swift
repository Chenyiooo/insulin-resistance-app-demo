import Foundation

struct LocalNutritionEstimator {
    private struct FoodProfile {
        let calories: Double
        let carbohydrates: Double
        let protein: Double
        let fat: Double
        let aliases: [String]
    }

    private static let foods: [String: FoodProfile] = [
        "rice": FoodProfile(calories: 205, carbohydrates: 45, protein: 4, fat: 0.4, aliases: ["rice", "white rice", "brown rice"]),
        "chicken": FoodProfile(calories: 165, carbohydrates: 0, protein: 31, fat: 3.6, aliases: ["chicken", "chicken breast"]),
        "egg": FoodProfile(calories: 72, carbohydrates: 0.4, protein: 6.3, fat: 4.8, aliases: ["egg", "eggs"]),
        "bread": FoodProfile(calories: 80, carbohydrates: 15, protein: 3, fat: 1, aliases: ["bread", "toast"]),
        "oatmeal": FoodProfile(calories: 154, carbohydrates: 27, protein: 6, fat: 3, aliases: ["oatmeal", "oats"]),
        "banana": FoodProfile(calories: 105, carbohydrates: 27, protein: 1.3, fat: 0.4, aliases: ["banana"]),
        "apple": FoodProfile(calories: 95, carbohydrates: 25, protein: 0.5, fat: 0.3, aliases: ["apple"]),
        "salad": FoodProfile(calories: 120, carbohydrates: 12, protein: 4, fat: 7, aliases: ["salad"]),
        "pasta": FoodProfile(calories: 220, carbohydrates: 43, protein: 8, fat: 1.3, aliases: ["pasta", "spaghetti", "noodles"]),
        "beef": FoodProfile(calories: 250, carbohydrates: 0, protein: 26, fat: 15, aliases: ["beef", "steak"]),
        "fish": FoodProfile(calories: 180, carbohydrates: 0, protein: 25, fat: 8, aliases: ["fish", "salmon", "tuna"]),
        "tofu": FoodProfile(calories: 145, carbohydrates: 4, protein: 16, fat: 9, aliases: ["tofu"]),
        "beans": FoodProfile(calories: 225, carbohydrates: 40, protein: 15, fat: 1, aliases: ["beans", "black beans", "lentils"]),
        "potato": FoodProfile(calories: 160, carbohydrates: 37, protein: 4, fat: 0.2, aliases: ["potato", "potatoes"]),
        "yogurt": FoodProfile(calories: 150, carbohydrates: 17, protein: 9, fat: 4, aliases: ["yogurt"]),
        "pizza": FoodProfile(calories: 285, carbohydrates: 36, protein: 12, fat: 10, aliases: ["pizza"]),
        "burger": FoodProfile(calories: 540, carbohydrates: 40, protein: 25, fat: 30, aliases: ["burger", "hamburger"]),
        "fries": FoodProfile(calories: 365, carbohydrates: 48, protein: 4, fat: 17, aliases: ["fries", "french fries"]),
    ]

    static func estimate(text: String, imageCount: Int) -> NutritionEstimateResponse {
        let normalized = text.lowercased()
        var calories = 0.0
        var carbohydrates = 0.0
        var protein = 0.0
        var fat = 0.0
        var matchedFoods: [String] = []

        for (name, profile) in foods {
            guard profile.aliases.contains(where: { normalized.contains($0) }) else { continue }
            let multiplier = portionMultiplier(for: normalized)
            calories += profile.calories * multiplier
            carbohydrates += profile.carbohydrates * multiplier
            protein += profile.protein * multiplier
            fat += profile.fat * multiplier
            matchedFoods.append(multiplier == 1 ? name : "\(Self.format(multiplier))x \(name)")
        }

        if matchedFoods.isEmpty && imageCount > 0 {
            let servings = Double(max(1, min(imageCount, 4)))
            return NutritionEstimateResponse(
                calories: Int(450 * servings),
                carbohydrates: 48 * servings,
                protein: 22 * servings,
                fat: 16 * servings,
                matchedFoods: ["photo meal estimate"],
                source: "photo_fallback",
                confidence: "low",
                explanation: "The backend nutrition service was unavailable, so this is a generic meal estimate from the uploaded photo count.",
                disclaimer: "Nutrition values are estimates for reflection only."
            )
        }

        return NutritionEstimateResponse(
            calories: Int(calories.rounded()),
            carbohydrates: round(carbohydrates * 10) / 10,
            protein: round(protein * 10) / 10,
            fat: round(fat * 10) / 10,
            matchedFoods: matchedFoods,
            source: "ios_local_rules",
            confidence: matchedFoods.count >= 2 ? "medium" : "low",
            explanation: matchedFoods.isEmpty ? "No recognizable food was found." : "Estimated on device from common serving-size nutrition values.",
            disclaimer: "Nutrition values are estimates for reflection only."
        )
    }

    private static func portionMultiplier(for text: String) -> Double {
        var multiplier = 1.0
        if text.contains("two ") || text.contains("2 ") { multiplier = 2 }
        if text.contains("three ") || text.contains("3 ") { multiplier = 3 }
        if text.contains("half") { multiplier *= 0.5 }
        if text.contains("small") { multiplier *= 0.75 }
        if text.contains("large") { multiplier *= 1.25 }
        return max(0.25, min(multiplier, 6))
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
