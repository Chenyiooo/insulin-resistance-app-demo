import Foundation

#if os(iOS)
import HealthKit
#endif

struct HealthImportResult {
    var sleepHours: Double?
    var activityName: String?
    var activityMinutes: Int?
    var weightPounds: Double?
    var systolic: Double?
    var diastolic: Double?

    var hasAnyData: Bool {
        sleepHours != nil ||
        activityMinutes != nil ||
        weightPounds != nil ||
        systolic != nil ||
        diastolic != nil
    }
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
            let result = try await HealthImportResult(
                sleepHours: sleepHours,
                activityName: workoutSummary?.name,
                activityMinutes: workoutSummary?.minutes,
                weightPounds: weight,
                systolic: systolic,
                diastolic: diastolic
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
}

private func todayPredicate() -> NSPredicate {
    let start = Calendar.current.startOfDay(for: Date())
    let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? Date()
    return HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
}

private func fetchSleepHours(store: HKHealthStore) async throws -> Double? {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
        return nil
    }
    let descriptor = HKSampleQueryDescriptor(
        predicates: [.categorySample(type: type, predicate: todayPredicate())],
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
    let firstName = workouts.first.map { workoutName(for: $0.workoutActivityType) } ?? "Workout"
    return WorkoutSummary(name: firstName, minutes: Int((totalSeconds / 60).rounded()))
}

private func fetchLatestQuantity(
    store: HKHealthStore,
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit
) async throws -> Double? {
    guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
        return nil
    }
    let descriptor = HKSampleQueryDescriptor(
        predicates: [.quantitySample(type: type, predicate: todayPredicate())],
        sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
        limit: 1
    )
    let samples = try await descriptor.result(for: store)
    return samples.first?.quantity.doubleValue(for: unit)
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
