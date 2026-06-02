//
//  HealthManager.swift
//  Aquack
//

import HealthKit
import OSLog

@MainActor
final class HealthManager {

    static let shared = HealthManager()

    let store = HKHealthStore()
    private static let log = Logger(subsystem: "com.xiaomingli.aquack", category: "Health")

    static var readTypes: Set<HKObjectType> {
        guard let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        return [steps]
    }

    private var stepType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .stepCount)
    }

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable() && stepType != nil
    }

    /// Call after the system Health permission sheet completes.
    func connectSteps() async -> Double {
        await fetchTodaySteps()
    }

    func fetchTodaySteps() async -> Double {
        guard HKHealthStore.isHealthDataAvailable(), let steps = stepType else { return 0 }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: [])

        let statsSteps = await statisticsStepCount(steps: steps, predicate: predicate)
        if statsSteps > 0 { return statsSteps }
        return await sampleQueryStepCount(steps: steps, predicate: predicate)
    }

    private func statisticsStepCount(steps: HKQuantityType, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: steps,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    Self.log.error("Statistics: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }
            store.execute(query)
        }
    }

    private func sampleQueryStepCount(steps: HKQuantityType, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: steps,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    Self.log.error("Samples: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: 0)
                    return
                }
                let total = (samples as? [HKQuantitySample])?
                    .reduce(0.0) { $0 + $1.quantity.doubleValue(for: .count()) } ?? 0
                continuation.resume(returning: total)
            }
            store.execute(query)
        }
    }
}
