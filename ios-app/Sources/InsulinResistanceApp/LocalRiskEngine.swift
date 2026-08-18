import Foundation

struct DailyInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let whatWeNoticed: String
    let whyItMayMatter: String
    let nextStep: String

    var detail: String {
        nextStep
    }

    init(icon: String, title: String, detail: String) {
        self.icon = icon
        self.title = title
        self.whatWeNoticed = "Today's record was reviewed."
        self.whyItMayMatter = "Small daily habits can be related to metabolic health over time."
        self.nextStep = detail
    }

    init(icon: String, title: String, whatWeNoticed: String, whyItMayMatter: String, nextStep: String) {
        self.icon = icon
        self.title = title
        self.whatWeNoticed = whatWeNoticed
        self.whyItMayMatter = whyItMayMatter
        self.nextStep = nextStep
    }
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
                insights.append(DailyInsight(
                    icon: "figure.walk",
                    title: "Physical activity",
                    detail: "You logged at least 30 minutes of activity today. Keep the same realistic routine when you can."
                ))
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
            insights.append(DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                detail: "You took frequent movement breaks today. Try to keep that pattern during long sitting periods."
            ))
        case "A few times during the day":
            score -= 2
            decreasing.append("Some movement breaks")
            insights.append(DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                detail: "Try standing or walking for 2-3 minutes during your next hour of sitting."
            ))
        case "Once":
            insights.append(DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                detail: "You logged one movement break. Add one more short standing or walking break during a long sitting period."
            ))
        case "Not at all":
            score += 4
            increasing.append("No movement breaks logged")
            insights.append(DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                detail: "A brief standing break during long sitting periods is a realistic next step."
            ))
        case "I did not spend much time sitting today":
            decreasing.append("Limited sitting time today")
            insights.append(DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                detail: "You did not spend much time sitting today, so no extra sitting-break action is needed from this log."
            ))
        default:
            break
        }

        if checkIn.foodJournal == "Added" {
            decreasing.append("Food journal added")
            insights.append(DailyInsight(
                icon: "fork.knife",
                title: "Food journal",
                detail: foodInsightDetail(for: checkIn)
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
            dailyInsights(for: checkIn)
        )
    }

    private static func dailyInsights(for checkIn: DailyCheckIn) -> [DailyInsight] {
        var cards = [
            sleepInsight(for: checkIn),
            activityInsight(for: checkIn),
            movementInsight(for: checkIn),
        ]
        if checkIn.foodJournal == "Added" {
            cards.append(foodInsight(for: checkIn))
        }
        return cards
    }

    private static func sleepInsight(for checkIn: DailyCheckIn) -> DailyInsight {
        guard let sleep = double(checkIn.sleepHours) else {
            return DailyInsight(
                icon: "moon.zzz",
                title: "Sleep",
                whatWeNoticed: "No sleep duration was logged for last night.",
                whyItMayMatter: "Without sleep information, the app should not guess how sleep may relate to today's routine.",
                nextStep: "Try logging sleep hours tomorrow if you have them."
            )
        }
        if sleep < 6 {
            return DailyInsight(
                icon: "moon.zzz",
                title: "Sleep",
                whatWeNoticed: "You slept for about \(format(sleep)) hours last night.",
                whyItMayMatter: "Getting enough sleep may support energy regulation and metabolic health.",
                nextStep: "If possible, begin your bedtime routine 15 minutes earlier tonight."
            )
        }
        if sleep <= 9 {
            return DailyInsight(
                icon: "moon.zzz",
                title: "Sleep",
                whatWeNoticed: "You slept for about \(format(sleep)) hours last night.",
                whyItMayMatter: "A consistent, sufficient sleep window may support daily energy and metabolic health.",
                nextStep: "Try keeping a similar sleep schedule tomorrow."
            )
        }
        return DailyInsight(
            icon: "moon.zzz",
            title: "Sleep",
            whatWeNoticed: "You logged about \(format(sleep)) hours of sleep last night.",
            whyItMayMatter: "Long sleep can happen for many reasons, so one day should not be interpreted as a medical signal.",
            nextStep: "If this pattern continues, note how your energy feels during the day."
        )
    }

    private static func activityInsight(for checkIn: DailyCheckIn) -> DailyInsight {
        if checkIn.activeToday == nil {
            return DailyInsight(
                icon: "figure.walk",
                title: "Physical activity",
                whatWeNoticed: "No physical activity answer was logged today.",
                whyItMayMatter: "Without activity information, the app should not infer whether today was active or inactive.",
                nextStep: "Try answering the activity question tomorrow, even if the answer is no."
            )
        }
        if checkIn.activeToday == false {
            return DailyInsight(
                icon: "figure.walk",
                title: "Physical activity",
                whatWeNoticed: "You reported no moderate, vigorous, or strengthening activity today.",
                whyItMayMatter: "Even brief activity can support daily energy use and insulin sensitivity over time.",
                nextStep: "Tomorrow, try one low-barrier option, such as a 5- to 10-minute walk."
            )
        }

        let duration = int(checkIn.activityDuration) ?? 0
        let type = checkIn.activityType.trimmingCharacters(in: .whitespacesAndNewlines)
        let logged = type.isEmpty
            ? "You reported being physically active today."
            : "You logged \(type.lowercased())\(duration > 0 ? " for about \(duration) minutes" : "")."
        let isStrength = type.lowercased().contains("strength")
        if duration > 0 && duration < 30 {
            return DailyInsight(
                icon: isStrength ? "dumbbell" : "figure.walk",
                title: "Physical activity",
                whatWeNoticed: logged,
                whyItMayMatter: "Some activity is meaningful, and adding a little more can support metabolic health habits.",
                nextStep: "Tomorrow, try adding 5 more minutes if that feels realistic."
            )
        }
        return DailyInsight(
            icon: isStrength ? "dumbbell" : "figure.walk",
            title: "Physical activity",
            whatWeNoticed: logged,
            whyItMayMatter: "Regular movement, including aerobic or strengthening activity, may support insulin sensitivity over time.",
            nextStep: isStrength ? "Tomorrow, consider a short walk if it fits your day." : "Try keeping this activity pattern tomorrow."
        )
    }

    private static func movementInsight(for checkIn: DailyCheckIn) -> DailyInsight {
        switch checkIn.movementBreaks {
        case "About once an hour or more":
            return DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                whatWeNoticed: "You took movement breaks about once an hour or more while sitting.",
                whyItMayMatter: "Breaking up long sitting periods may support glucose and energy regulation.",
                nextStep: "Try keeping that same break pattern tomorrow."
            )
        case "A few times during the day":
            return DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                whatWeNoticed: "You took movement breaks a few times today.",
                whyItMayMatter: "Short breaks can reduce long uninterrupted sitting time.",
                nextStep: "Tomorrow, attach one extra 2- to 3-minute break to a fixed moment, such as after lunch."
            )
        case "Once":
            return DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                whatWeNoticed: "You logged one movement break today.",
                whyItMayMatter: "Starting small can make movement breaks easier to repeat.",
                nextStep: "Tomorrow, try adding one extra 2- to 3-minute standing or walking break."
            )
        case "Not at all":
            return DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                whatWeNoticed: "You reported no movement breaks during sitting periods today.",
                whyItMayMatter: "Long uninterrupted sitting may be related to daily metabolic patterns.",
                nextStep: "Tomorrow, choose one long sitting period and add one 2- to 3-minute break."
            )
        case "I did not spend much time sitting today":
            return DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                whatWeNoticed: "You did not spend much time sitting today.",
                whyItMayMatter: "Less sitting means movement breaks may be less relevant for this particular day.",
                nextStep: "No extra sitting-break action is needed from this log."
            )
        default:
            return DailyInsight(
                icon: "figure.stand",
                title: "Movement breaks",
                whatWeNoticed: "No movement-break answer was logged today.",
                whyItMayMatter: "Without this answer, the app should not guess how much sitting was interrupted.",
                nextStep: "Try answering the movement-break question tomorrow."
            )
        }
    }

    private static func foodInsight(for checkIn: DailyCheckIn) -> DailyInsight {
        DailyInsight(
            icon: "fork.knife",
            title: "Food reflection",
            whatWeNoticed: foodNoticedText(for: checkIn),
            whyItMayMatter: "Meal timing and food combinations can be useful context when reflecting on energy, hunger, and metabolic health patterns.",
            nextStep: foodNextStep(for: checkIn)
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

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private static func foodNoticedText(for checkIn: DailyCheckIn) -> String {
        let description = checkIn.foodJournalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            return "You added a food journal note: \(description)"
        }
        if checkIn.foodPhotoCount > 0 {
            return "You uploaded \(checkIn.foodPhotoCount) food photo\(checkIn.foodPhotoCount == 1 ? "" : "s") today."
        }
        return "You added a food journal today."
    }

    private static func foodNextStep(for checkIn: DailyCheckIn) -> String {
        let carbs = double(checkIn.foodCarbohydrates)
        let protein = double(checkIn.foodProtein)
        let text = checkIn.foodJournalDescription.lowercased()
        if text.contains("soda") || text.contains("juice") || text.contains("sweet") {
            return "Tomorrow, notice whether swapping one sweet drink for water or unsweetened tea feels realistic."
        }
        if let carbs, carbs >= 75, let protein, protein < 20 {
            return "Tomorrow, try pairing a carbohydrate-rich meal with one protein source."
        }
        if let carbs, carbs >= 75 {
            return "Tomorrow, notice how hunger or energy feels after a carbohydrate-heavy meal."
        }
        if let protein, protein >= 20 {
            return "Tomorrow, notice whether a similar protein-containing meal helps fullness or energy."
        }
        return "Tomorrow, add one detail about timing, vegetables, protein, or drinks if you log food again."
    }

    private static func foodInsightDetail(for checkIn: DailyCheckIn) -> String {
        let carbs = double(checkIn.foodCarbohydrates)
        let protein = double(checkIn.foodProtein)
        if let carbs, carbs >= 75, let protein, protein < 20 {
            return "This log looks higher in carbohydrates and lower in protein. At a future meal, consider pairing carbs with a protein source."
        }
        if let carbs, carbs >= 75 {
            return "This meal estimate is higher in carbohydrates. Notice how energy or hunger feels afterward."
        }
        if let protein, protein >= 20 {
            return "You logged a meal with a meaningful protein source. Notice whether it helped fullness or energy."
        }
        return "Your food log is saved. Use it later to compare meals with energy, hunger, or activity patterns."
    }
}
