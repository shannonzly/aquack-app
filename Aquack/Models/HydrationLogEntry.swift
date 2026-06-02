//
//  HydrationLogEntry.swift
//  Aquack
//

import Foundation
import SwiftData

@Model
final class HydrationLogEntry {
    var timestamp: Date
    var ounces: Double
    var source: String
    var note: String?

    init(
        timestamp: Date = .now,
        ounces: Double,
        source: String = "manual",
        note: String? = nil
    ) {
        self.timestamp = timestamp
        self.ounces = ounces
        self.source = source
        self.note = note
    }
}

