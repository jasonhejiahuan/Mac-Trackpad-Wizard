import Foundation
import Observation

@MainActor
@Observable
final class HapticStatisticsStore {
    private(set) var isCollectionEnabled: Bool
    private(set) var devices: [DeviceHapticStatistics]
    var graphRange: StatisticsGraphRange {
        didSet { defaults.set(graphRange.rawValue, forKey: DefaultsKey.graphRange) }
    }
    private(set) var lastPersistenceError: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let archiveURL: URL
    @ObservationIgnored private let persistenceQueue = DispatchQueue(
        label: "cc.jasonstu.trackpadwizard.statistics-persistence",
        qos: .utility
    )
    @ObservationIgnored private let accumulator = HapticCountAccumulator()
    @ObservationIgnored private var flushTimer: Timer?

    private enum DefaultsKey {
        static let collectionEnabled = "hapticStatisticsCollectionEnabled"
        static let graphRange = "hapticStatisticsGraphRange"
    }

    init(
        defaults: UserDefaults = .standard,
        archiveURL: URL? = nil
    ) {
        self.defaults = defaults
        self.archiveURL = archiveURL ?? Self.defaultArchiveURL
        isCollectionEnabled = defaults.object(forKey: DefaultsKey.collectionEnabled) as? Bool ?? true
        graphRange = StatisticsGraphRange(
            rawValue: defaults.integer(forKey: DefaultsKey.graphRange)
        ) ?? .month
        devices = Self.loadArchive(from: self.archiveURL)
        if isCollectionEnabled {
            startFlushTimer()
        }
    }

    var totalCount: UInt64 {
        devices.reduce(0) { $0 + $1.totalCount }
    }

    var actuationObserver: (@Sendable (HapticCounterDevice) -> Void)? {
        guard isCollectionEnabled else { return nil }
        let accumulator = accumulator
        return { device in
            accumulator.record(device)
        }
    }

    func setCollectionEnabled(_ enabled: Bool) {
        guard isCollectionEnabled != enabled else { return }
        if !enabled {
            flushPendingCounts()
            flushTimer?.invalidate()
            flushTimer = nil
        }
        isCollectionEnabled = enabled
        defaults.set(enabled, forKey: DefaultsKey.collectionEnabled)
        if enabled {
            startFlushTimer()
        }
    }

    func flushPendingCounts() {
        let pending = accumulator.drain()
        guard !pending.isEmpty else { return }

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        for (identity, increment) in pending {
            guard increment > 0 else { continue }
            if let deviceIndex = devices.firstIndex(where: { $0.id == identity.id }) {
                devices[deviceIndex].displayName = identity.displayName
                devices[deviceIndex].totalCount &+= increment
                if let dayIndex = devices[deviceIndex].dailyCounts.firstIndex(where: {
                    calendar.isDate($0.day, inSameDayAs: today)
                }) {
                    devices[deviceIndex].dailyCounts[dayIndex].count &+= increment
                } else {
                    devices[deviceIndex].dailyCounts.append(
                        DailyHapticCount(day: today, count: increment)
                    )
                }
                devices[deviceIndex].dailyCounts.sort { $0.day < $1.day }
            } else {
                devices.append(
                    DeviceHapticStatistics(
                        id: identity.id,
                        displayName: identity.displayName,
                        isBuiltIn: identity.isBuiltIn,
                        totalCount: increment,
                        dailyCounts: [DailyHapticCount(day: today, count: increment)]
                    )
                )
                devices.sort { lhs, rhs in
                    if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn }
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
            }
        }
        persist()
    }

    func reset() {
        accumulator.reset()
        devices = []
        persist()
    }

    func counts(for device: DeviceHapticStatistics) -> [DailyHapticCount] {
        guard graphRange.rawValue > 0 else { return device.dailyCounts }
        let cutoff = Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: -(graphRange.rawValue - 1),
            to: Calendar.autoupdatingCurrent.startOfDay(for: .now)
        ) ?? .distantPast
        return device.dailyCounts.filter { $0.day >= cutoff }
    }

    func shutDown() {
        flushPendingCounts()
        flushTimer?.invalidate()
        flushTimer = nil
        // App termination must not abandon the final shutter-count-style write.
        persistenceQueue.sync {}
    }

    private func startFlushTimer() {
        guard flushTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flushPendingCounts()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        flushTimer = timer
    }

    private func persist() {
        lastPersistenceError = nil
        let archive = HapticStatisticsArchive(
            schemaVersion: 1,
            savedAt: .now,
            devices: devices
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(archive) else {
            lastPersistenceError = "Statistics could not be encoded."
            return
        }

        let archiveURL = archiveURL
        persistenceQueue.async { [weak self] in
            do {
                try FileManager.default.createDirectory(
                    at: archiveURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: archiveURL, options: .atomic)
            } catch {
                Task { @MainActor [weak self] in
                    self?.lastPersistenceError = error.localizedDescription
                }
            }
        }
    }

    private static func loadArchive(from url: URL) -> [DeviceHapticStatistics] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        guard let archive = try? decoder.decode(HapticStatisticsArchive.self, from: data),
              archive.schemaVersion == 1 else { return [] }
        return archive.devices
    }

    private static var defaultArchiveURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Trackpad Wizard", isDirectory: true)
            .appendingPathComponent("Haptic Statistics.json", isDirectory: false)
    }
}

private final class HapticCountAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [HapticCounterDevice: UInt64] = [:]

    func record(_ device: HapticCounterDevice) {
        lock.lock()
        pending[device, default: 0] &+= 1
        lock.unlock()
    }

    func drain() -> [HapticCounterDevice: UInt64] {
        lock.lock()
        let result = pending
        pending.removeAll(keepingCapacity: true)
        lock.unlock()
        return result
    }

    func reset() {
        lock.lock()
        pending.removeAll()
        lock.unlock()
    }
}
