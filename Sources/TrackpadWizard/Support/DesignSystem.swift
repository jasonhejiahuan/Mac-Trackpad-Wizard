import SwiftUI

struct GlassCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    private let trailing: Trailing

    init(
        _ title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 20)
            trailing
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    var detail: String?

    var body: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 13) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct StatusPill: View {
    let text: String
    let systemImage: String
    var isActive = false

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(isActive ? .primary : .secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .glassEffect(
                isActive ? .regular.interactive() : .clear,
                in: Capsule()
            )
    }
}

struct FeatureRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct InlineNotice: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension View {
    func pageLayout() -> some View {
        self
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
