import Foundation

struct DailyInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

enum LocalRiskEngine {
    static func evaluate(profile: UserProfile, checkIn: DailyCheckIn) -> (risk: WeeklyRisk, insights: [DailyInsight]) {
        var score = 35
        var increasing: [String] = []
        var decreasing: [String] = []
        var insights: [DailyInsight] = []

        let age = int(profile.age)
        if let age {
            if age >= 45 {
                score += 8
                increasing.append("Age 45 or older")
            } else if age < 35 {
                score -= 4
                decreasing.append("Younger age")
            }
        }

        let heightInches = heightInches(feet: profile.heightFeet, inches: profile.heightInches)
        let weightLb = weightInPounds(value: checkIn.weight, unit: checkIn.weightUnit)
        if let heightInches, let weightLb, heightInches > 0 {
            let bmi = weightLb / (heightInches * heightInches) * 703
            if bmi >= 30 {
                score += 12
                increasing.append("BMI in the obesity range")
            } else if bmi >= 25 {
                score += 7
                increasing.append("BMI in the overweight range")
            } else if bmi >= 18.5 {
                score -= 3
                decreasing.append("BMI in the typical range")
            }
        }

        if let waist = double(checkIn.waist) {
            let waistIn = checkIn.waistUnit == "cm" ? waist / 2.54 : waist
            if waistIn >= 40 {
                score += 12
                increasing.append("Higher waist circumference")
            } else if waistIn >= 35 {
                score += 8
                increasing.append("Waist circumference may be elevated")
            } else if waistIn > 0 {
                score -= 2
                decreasing.append("Waist circumference in a lower range")
            }
        }

        if checkIn.hasRecentBloodPressure,
           let systolic = int(checkIn.systolic),
           let diastolic = int(checkIn.diastolic) {
            if systolic >= 140 || diastolic >= 90 {
                score += 10
                increasing.append("Recent blood pressure in a high range")
            } else if systolic >= 130 || diastolic >= 80 {
                score += 5
                increasing.append("Recent blood pressure may be elevated")
            } else {
                score -= 3
                decreasing.append("Recent blood pressure in a lower range")
            }
        }

        if profile.hypertensionHistory == "Yes" {
            score += 8
            increasing.append("History of high blood pressure")
        }
        if profile.highCholesterol == "Yes" {
            score += 6
            increasing.append("History of high cholesterol")
        }
        if profile.familyHistoryDiabetes == "Yes" {
            score += 8
            increasing.append("Close family history of diabetes")
        }
        if profile.gestationalDiabetes == "Yes" {
            score += 10
            increasing.append("History of gestational diabetes")
        }
        if profile.smokingStatus.contains("Currently") {
            score += 7
            increasing.append("Current smoking")
        } else if profile.smokingStatus == "Never smoked" {
            score -= 3
            decreasing.append("No current smoking history reported")
        }

        if let sleep = double(checkIn.sleepHours) {
            if sleep < 6 {
                score += 6
                increasing.append("Short sleep duration")
                insights.append(DailyInsight(
                    icon: "moon.zzz",
                    title: "Sleep",
                    detail: "A slightly earlier wind-down tonight could help move sleep closer to 7 hours."
                ))
            } else if sleep <= 9 {
                score -= 4
                decreasing.append("Typical sleep duration")
                insights.append(DailyInsight(
                    icon: "moon.zzz",
                    title: "Sleep",
                    detail: "Your sleep duration is in a supportive range today."
                ))
            }
        }

        if checkIn.activeToday == true {
            let duration = int(checkIn.activityDuration) ?? 0
            if duration >= 30 {
                score -= 8
                decreasing.append("At least 30 minutes of activity")
            } else if duration > 0 {
                score -= 5
                decreasing.append("Some physical activity today")
                insights.append(DailyInsight(
                    icon: "figure.walk",
                    title: "Physical activity",
                    detail: "A 10-minute walk after your next meal could add a little more movement."
                ))
            }
        } else if checkIn.activeToday == false {
            score += 5
            increasing.append("No moderate or vigorous activity logged today")
            insights.append(DailyInsight(
                icon: "figure.walk",
                title: "Physical activity",
                detail: "A short walk or gentle activity break can still count today."
            ))
        }

        switch checkIn.movementBreaks {
        case "About once an hour or more":
            score -= 5
            decreasing.append("Frequent movement breaks")
        case "A few times during the day":
            score -= 2
            decreasing.append("Some movement breaks")
            insights.append(DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                detail: "Try standing or walking for 2-3 minutes during your next hour of sitting."
            ))
        case "Not at all":
            score += 4
            increasing.append("No movement breaks logged")
            insights.append(DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                detail: "A brief standing break during long sitting periods is a realistic next step."
            ))
        default:
            break
        }

        if checkIn.foodJournal == "Added" {
            decreasing.append("Food journal added")
            insights.append(DailyInsight(
                icon: "fork.knife",
                title: "Food journal",
                detail: "Review today's meals and notice anything that stood out."
            ))
        } else {
            insights.append(DailyInsight(
                icon: "fork.knife",
                title: "Food journal",
                detail: "Adding a quick food note can make patterns easier to spot later."
            ))
        }

        if insights.isEmpty {
            insights.append(DailyInsight(
                icon: "sparkles",
                title: "Reflection",
                detail: "Notice one small routine that felt supportive today and repeat it tomorrow."
            ))
        }

        score = min(max(score, 5), 95)
        let band: String
        if score >= 65 {
            band = "High Risk"
        } else if score >= 40 {
            band = "Moderate Risk"
        } else {
            band = "Lower Risk"
        }

        if increasing.isEmpty {
            increasing = ["No major increasing factors from today's saved data"]
        }
        if decreasing.isEmpty {
            decreasing = ["No major decreasing factors from today's saved data"]
        }

        return (
            WeeklyRisk(
                score: score,
                band: band,
                increasing: Array(NSOrderedSet(array: increasing).compactMap { $0 as? String }.prefix(5)),
                decreasing: Array(NSOrderedSet(array: decreasing).compactMap { $0 as? String }.prefix(5))
            ),
            Array(insights.prefix(4))
        )
    }

    private static func int(_ value: String) -> Int? {
        Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func double(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func heightInches(feet: String, inches: String) -> Double? {
        guard let feetValue = double(feet), let inchesValue = double(inches) else {
            return nil
        }
        return feetValue * 12 + inchesValue
    }

    private static func weightInPounds(value: String, unit: String) -> Double? {
        guard let weight = double(value) else { return nil }
        return unit == "kg" ? weight * 2.20462 : weight
    }
}
