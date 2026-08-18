import Foundation

#if os(iOS)
import HealthKit
#endif

struct HealthImportResult {
    var sleepHours: Double?
    var activityName: String?
    var activityMinutes: Int?
    var activities: [ImportedHealthActivity] = []
    var weightPounds: Double?
    var weightDate: Date?
    var systolic: Double?
    var diastolic: Double?
    var bloodPressureDate: Date?

    var hasAnyData: Bool {
        sleepHours != nil ||
        activityMinutes != nil ||
        !activities.isEmpty ||
        weightPounds != nil ||
        systolic != nil ||
        diastolic != nil
    }
}

struct ImportedHealthActivity: Identifiable {
    let id = UUID()
    let name: String
    let minutes: Int
}

enum HealthImportState {
    case idle
    case loading
    case loaded(HealthImportResult)
    case unavailable(String)
    case failed(String)
}

@MainActor
final class HealthKitService: ObservableObject {
    @Published var state: HealthImportState = .idle

    func requestAndFetchToday() async {
#if os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else {
            state = .unavailable("Health data is not available on this device or simulator.")
            return
        }

        state = .loading
        let store = HKHealthStore()
        let readTypes = Set([
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)
        ].compactMap { $0 })

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            async let sleep = fetchSleepHours(store: store)
            async let workout = fetchWorkoutSummary(store: store)
            async let weight = fetchLatestQuantity(
                store: store,
                identifier: .bodyMass,
                unit: .pound()
            )
            async let systolic = fetchLatestQuantity(
                store: store,
                identifier: .bloodPressureSystolic,
                unit: .millimeterOfMercury()
            )
            async let diastolic = fetchLatestQuantity(
                store: store,
                identifier: .bloodPressureDiastolic,
                unit: .millimeterOfMercury()
            )

            let sleepHours = try await sleep
            let workoutSummary = try await workout
            let weightReading = try await weight
            let systolicReading = try await systolic
            let diastolicReading = try await diastolic
            let bloodPressureDate = [systolicReading?.date, diastolicReading?.date]
                .compactMap { $0 }
                .max()
            let result = HealthImportResult(
                sleepHours: sleepHours,
                activityName: workoutSummary?.name,
                activityMinutes: workoutSummary?.minutes,
                activities: workoutSummary?.activities ?? [],
                weightPounds: weightReading?.value,
                weightDate: weightReading?.date,
                systolic: systolicReading?.value,
                diastolic: diastolicReading?.value,
                bloodPressureDate: bloodPressureDate
            )
            state = .loaded(result)
        } catch {
            state = .failed(error.localizedDescription)
        }
#else
        state = .unavailable("HealthKit is only available on iPhone.")
#endif
    }

    func reset() {
        state = .idle
    }
}

#if os(iOS)
private struct WorkoutSummary {
    let name: String
    let minutes: Int
    let activities: [ImportedHealthActivity]
}

private struct QuantityReading {
    let value: Double
    let date: Date
}

private func todayPredicate(options: HKQueryOptions = .strictStartDate) -> NSPredicate {
    let start = Calendar.current.startOfDay(for: Date())
    let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
    return HKQuery.predicateForSamples(withStart: start, end: end, options: options)
}

private func lastNightSleepPredicate() -> NSPredicate {
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    let noonToday = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfToday) ?? Date()
    let noonYesterday = calendar.date(byAdding: .day, value: -1, to: noonToday) ?? startOfToday
    return HKQuery.predicateForSamples(withStart: noonYesterday, end: noonToday, options: [])
}

private func recentPredicate(days: Int) -> NSPredicate {
    let end = Date()
    let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
    return HKQuery.predicateForSamples(withStart: start, end: end, options: [])
}

private func fetchSleepHours(store: HKHealthStore) async throws -> Double? {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
        return nil
    }
    let descriptor = HKSampleQueryDescriptor(
        predicates: [.categorySample(type: type, predicate: lastNightSleepPredicate())],
        sortDescriptors: []
    )
    let samples = try await descriptor.result(for: store)
    let asleepValues: Set<Int> = [
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
    ]
    let seconds = samples
        .filter { asleepValues.contains($0.value) }
        .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
    return seconds > 0 ? seconds / 3600 : nil
}

private func fetchWorkoutSummary(store: HKHealthStore) async throws -> WorkoutSummary? {
    let descriptor = HKSampleQueryDescriptor(
        predicates: [.workout(todayPredicate())],
        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
    )
    let workouts = try await descriptor.result(for: store)
    let totalSeconds = workouts.reduce(0.0) { $0 + $1.duration }
    guard totalSeconds > 0 else { return nil }
    let activities = workouts.map {
        ImportedHealthActivity(
            name: workoutName(for: $0.workoutActivityType),
            minutes: Int(($0.duration / 60).rounded())
        )
    }
    let name = activities.count == 1 ? activities[0].name : "Multiple activities"
    return WorkoutSummary(name: name, minutes: Int((totalSeconds / 60).rounded()), activities: activities)
}

private func fetchLatestQuantity(
    store: HKHealthStore,
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit
) async throws -> QuantityReading? {
    guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
        return nil
    }
    let descriptor = HKSampleQueryDescriptor(
        predicates: [.quantitySample(type: type, predicate: recentPredicate(days: 30))],
        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
        limit: 1
    )
    let samples = try await descriptor.result(for: store)
    guard let sample = samples.first else { return nil }
    return QuantityReading(value: sample.quantity.doubleValue(for: unit), date: sample.startDate)
}

private func workoutName(for type: HKWorkoutActivityType) -> String {
    switch type {
    case .walking:
        return "Walking"
    case .running:
        return "Running"
    case .cycling:
        return "Cycling"
    case .traditionalStrengthTraining, .functionalStrengthTraining:
        return "Strength training"
    case .swimming:
        return "Swimming"
    case .yoga:
        return "Yoga"
    default:
        return "Workout"
    }
}
#endif
