import AppKit
import SwiftUI

struct DevicesView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    "Devices",
                    subtitle: "Live trackpad capabilities and the current macOS gesture preferences."
                ) {
                    HStack(spacing: 10) {
                        if let date = model.lastDeviceRefresh {
                            Text("Updated \(date, style: .relative)")
                        }
                        Button {
                            model.refreshDevices()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if model.devices.isEmpty {
                    GlassCard {
                        ContentUnavailableView(
                            "No Trackpad Reported",
                            systemImage: "rectangle.slash",
                            description: Text("Connect a trackpad and choose Refresh.")
                        )
                        .frame(minHeight: 230)
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 360), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(model.devices) { device in
                            DeviceCard(device: device)
                        }
                    }
                }

                AdaptiveColumnsLayout(breakpoint: 880, spacing: 18, trailingWidth: 330) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("macOS Trackpad Settings", systemImage: "switch.2")
                                    .font(.headline)
                                Spacer()
                                Button("Open System Settings") { openTrackpadSettings() }
                            }

                            if model.trackpadSettings.isEmpty {
                                Text("No readable trackpad preferences were reported for the current user.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                            } else {
                                Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 11) {
                                    ForEach(model.trackpadSettings) { setting in
                                        GridRow {
                                            Text(setting.title)
                                                .foregroundStyle(.secondary)
                                            Label(setting.value, systemImage: setting.indicator.systemImage)
                                                .fontWeight(.medium)
                                                .foregroundStyle(
                                                    setting.indicator == .enabled
                                                        ? AnyShapeStyle(.green)
                                                        : AnyShapeStyle(.primary)
                                                )
                                                .gridColumnAlignment(.trailing)
                                        }
                                        if setting.id != model.trackpadSettings.last?.id {
                                            Divider().gridCellColumns(2)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Group {
                        if model.showInterfaceHints {
                            GlassCard(padding: 15) {
                                VStack(alignment: .leading, spacing: 12) {
                                    InlineNotice(
                                        systemImage: "eye.slash",
                                        title: "Deliberately omitted",
                                        message: "The device view does not surface Bluetooth addresses, serial-like registry values, or private actuator identifiers. They are unnecessary for diagnostics here."
                                    )
                                    Divider()
                                    InlineNotice(
                                        systemImage: "waveform.path.ecg.rectangle",
                                        title: "Live, not cached",
                                        message: "Battery, connection, Force Touch support, and report interval come from the current I/O Registry snapshot and may be absent when a device or transport does not report them."
                                    )
                                }
                            }
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                }
            }
            .pageLayout()
        }
        .onAppear { model.refreshDevices() }
    }

    private func openTrackpadSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }
}

private struct DeviceCard: View {
    let device: TrackpadDevice

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 13) {
                    Image(systemName: "rectangle.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.secondary)
                        .frame(width: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        Label(device.connection.title, systemImage: device.connection.systemImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let battery = device.batteryPercent {
                        Label("\(battery)%", systemImage: batterySymbol(battery))
                            .font(.headline.monospacedDigit())
                    }
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow {
                        DeviceDatum(title: "Force Touch", value: forceValue)
                        DeviceDatum(
                            title: "Report Rate",
                            value: device.reportRate.map { "\(Int($0.rounded())) Hz" } ?? "Not reported"
                        )
                    }
                    GridRow {
                        DeviceDatum(
                            title: "Report Interval",
                            value: device.reportIntervalMicroseconds.map { "\($0) µs" } ?? "Not reported"
                        )
                        DeviceDatum(
                            title: "USB Identity",
                            value: usbIdentity
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
        }
    }

    private var forceValue: String {
        switch device.forceSupported {
        case true: "Supported"
        case false: "Not supported"
        case nil: "Not reported"
        }
    }

    private var usbIdentity: String {
        if device.isBuiltIn {
            return "Internal"
        }
        guard let vendorID = device.vendorID,
              let productID = device.productID,
              vendorID > 0,
              productID > 0 else {
            return "Not reported"
        }
        return String(format: "%04X : %04X", vendorID, productID)
    }

    private func batterySymbol(_ battery: Int) -> String {
        switch battery {
        case ..<15: "battery.0percent"
        case ..<40: "battery.25percent"
        case ..<65: "battery.50percent"
        case ..<90: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

private struct DeviceDatum: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
