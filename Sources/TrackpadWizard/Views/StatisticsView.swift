import Charts
import SwiftUI

struct StatisticsView: View {
    @Bindable var model: AppModel

    var body: some View {
        StatisticsContent(model: model, store: model.statisticsStore)
    }
}

private struct StatisticsContent: View {
    let model: AppModel
    @Bindable var store: HapticStatisticsStore
    @State private var selectedDeviceID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    "Statistics",
                    subtitle: "Persistent actuator counts, separated by trackpad."
                ) {
                    StatusPill(
                        text: store.isCollectionEnabled ? "Collecting" : "Collection Off",
                        systemImage: store.isCollectionEnabled ? "chart.bar.fill" : "pause.circle",
                        isActive: store.isCollectionEnabled
                    )
                }

                if store.devices.isEmpty {
                    GlassCard {
                        ContentUnavailableView(
                            "No Haptic Counts Yet",
                            systemImage: "chart.xyaxis.line",
                            description: Text(
                                store.isCollectionEnabled
                                    ? "Successful vibrations sent by Trackpad Wizard will appear here."
                                    : "Enable statistics collection in Settings to begin counting."
                            )
                        )
                        .frame(minHeight: 280)
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 230), spacing: 12)],
                        spacing: 12
                    ) {
                        MetricTile(
                            title: "All Trackpads",
                            value: store.totalCount.formatted(),
                            systemImage: "waveform",
                            detail: "Successful oscillations"
                        )
                        MetricTile(
                            title: "Tracked Devices",
                            value: store.devices.count.formatted(),
                            systemImage: "rectangle.stack.fill",
                            detail: "Locally pseudonymized"
                        )
                        MetricTile(
                            title: "Selected Trackpad",
                            value: selectedDevice?.totalCount.formatted() ?? "—",
                            systemImage: TrackpadSymbols.device(enhanced: model.enhancedModeEnabled),
                            detail: selectedDevice?.displayName ?? "Choose below"
                        )
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 14) {
                                Label("Vibration History", systemImage: "chart.bar.xaxis")
                                    .font(.headline)
                                Spacer()
                                Picker("Trackpad", selection: selectedDeviceBinding) {
                                    ForEach(store.devices) { device in
                                        Text(device.displayName).tag(Optional(device.id))
                                    }
                                }
                                .frame(maxWidth: 250)
                                Picker("Range", selection: $store.graphRange) {
                                    ForEach(StatisticsGraphRange.allCases) { range in
                                        Text(range.title).tag(range)
                                    }
                                }
                                .frame(width: 130)
                            }

                            if let selectedDevice {
                                Chart(chartData(for: selectedDevice)) { point in
                                    BarMark(
                                        x: .value("Day", point.day, unit: .day),
                                        y: .value("Oscillations", point.count)
                                    )
                                    .foregroundStyle(.primary.opacity(0.72))
                                    .cornerRadius(3)
                                }
                                .chartYAxisLabel("Oscillations")
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: 7)) {
                                        AxisGridLine()
                                        AxisTick()
                                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                    }
                                }
                                .frame(minHeight: 270)

                                HStack {
                                    Label(
                                        selectedDevice.isBuiltIn ? "Internal" : "External",
                                        systemImage: selectedDevice.isBuiltIn
                                            ? "laptopcomputer"
                                            : "antenna.radiowaves.left.and.right"
                                    )
                                    Spacer()
                                    Text("Lifetime total: \(selectedDevice.totalCount.formatted())")
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if model.showInterfaceHints {
                    GlassCard(padding: 15) {
                        InlineNotice(
                            systemImage: "gauge.open.with.lines.needle.33percent",
                            title: "Designed off the input path",
                            message: "Each successful app-generated actuator call adds one in-memory oscillation. Counts are batched to disk once per second. Turning collection off removes the observer and timer; no sleep or power assertion is used. Normal macOS clicks are not counted because the public event stream cannot reliably distinguish a trackpad from a mouse without a global monitor."
                        )
                    }
                }
            }
            .pageLayout()
        }
        .onAppear {
            store.flushPendingCounts()
            if selectedDeviceID == nil {
                selectedDeviceID = store.devices.first?.id
            }
        }
        .onChange(of: store.devices.map(\.id)) { _, ids in
            if let selectedDeviceID, ids.contains(selectedDeviceID) { return }
            selectedDeviceID = ids.first
        }
    }

    private var selectedDevice: DeviceHapticStatistics? {
        guard let selectedDeviceID else { return store.devices.first }
        return store.devices.first { $0.id == selectedDeviceID } ?? store.devices.first
    }

    private var selectedDeviceBinding: Binding<String?> {
        Binding(
            get: { selectedDevice?.id },
            set: { selectedDeviceID = $0 }
        )
    }

    private func chartData(for device: DeviceHapticStatistics) -> [DailyHapticCount] {
        let existing = Dictionary(uniqueKeysWithValues: store.counts(for: device).map { ($0.day, $0.count) })
        guard store.graphRange.rawValue > 0 else {
            return existing.map { DailyHapticCount(day: $0.key, count: $0.value) }
                .sorted { $0.day < $1.day }
        }

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        return (0..<store.graphRange.rawValue).compactMap { offset in
            guard let day = calendar.date(
                byAdding: .day,
                value: offset - (store.graphRange.rawValue - 1),
                to: today
            ) else { return nil }
            let count = existing.first { calendar.isDate($0.key, inSameDayAs: day) }?.value ?? 0
            return DailyHapticCount(day: day, count: count)
        }
    }
}
