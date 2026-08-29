import Foundation

struct HapticCounterDevice: Hashable, Sendable {
    let id: String
    let displayName: String
    let isBuiltIn: Bool
}

struct DailyHapticCount: Identifiable, Codable, Hashable, Sendable {
    let day: Date
    var count: UInt64

    var id: Date { day }
}

struct DeviceHapticStatistics: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var displayName: String
    let isBuiltIn: Bool
    var totalCount: UInt64
    var dailyCounts: [DailyHapticCount]

    var mostRecentDate: Date? {
        dailyCounts.map(\.day).max()
    }
}

struct HapticStatisticsArchive: Codable, Sendable {
    let schemaVersion: Int
    let savedAt: Date
    let devices: [DeviceHapticStatistics]
}

enum StatisticsGraphRange: Int, CaseIterable, Identifiable, Sendable {
    case week = 7
    case month = 30
    case quarter = 90
    case all = 0

    var id: Self { self }

    var title: String {
        switch self {
        case .week: "7 Days"
        case .month: "30 Days"
        case .quarter: "90 Days"
        case .all: "All Time"
        }
    }
}
