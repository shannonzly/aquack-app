//
//  CustomDrinkSizeStore.swift
//  Aquack
//

import Foundation

struct CustomDrinkSize: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var ounces: Double

    init(id: UUID = UUID(), name: String, ounces: Double) {
        self.id = id
        self.name = name
        self.ounces = ounces
    }
}

enum CustomDrinkSizeStore {
    private static let key = "customDrinkSizes"
    private static let maxCount = 12

    static func load() -> [CustomDrinkSize] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomDrinkSize].self, from: data) else {
            return []
        }
        return decoded
    }

    static func save(_ sizes: [CustomDrinkSize]) {
        let trimmed = Array(sizes.prefix(maxCount))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func add(name: String, ounces: Double) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, ounces > 0 else { return }
        var sizes = load()
        sizes.removeAll { $0.name.caseInsensitiveCompare(cleaned) == .orderedSame }
        sizes.insert(CustomDrinkSize(name: cleaned, ounces: ounces), at: 0)
        save(sizes)
    }

    static func delete(id: UUID) {
        var sizes = load()
        sizes.removeAll { $0.id == id }
        save(sizes)
    }
}
