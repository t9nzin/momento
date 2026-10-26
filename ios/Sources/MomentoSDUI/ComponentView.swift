import OSLog
import SwiftUI

/// Renders one component and, recursively, everything beneath it.
public struct ComponentView: View {
    let component: Component
    let scope: BindingScope

    public init(_ component: Component, scope: BindingScope) {
        self.component = component
        self.scope = scope
    }

    public var body: some View {
        switch component {
        case .column(let node):
            Tappable(action: node.action, scope: scope) {
                VStack(alignment: .leading, spacing: node.props?.spacing ?? 0) {
                    children(node.children)
                }
            }
        case .row(let node):
            Tappable(action: node.action, scope: scope) {
                HStack(spacing: node.props?.spacing ?? 0) {
                    children(node.children)
                }
            }
        case .text(let node):
            SDUIText(text: scope.string(node.props.text), style: node.props.style)
        case .image(let node):
            SDUIImage(url: scope.string(node.props.url), alt: scope.optionalString(node.props.alt),
                      aspectRatio: node.props.aspectRatio)
        case .card(let node):
            Tappable(action: node.action, scope: scope) {
                SDUICard(imageURL: scope.optionalString(node.props.imageUrl),
                         title: scope.string(node.props.title),
                         subtitle: scope.optionalString(node.props.subtitle))
            }
        case .grid(let node):
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                                count: max(1, node.props.columns))
            LazyVGrid(columns: columns, spacing: 12) {
                templateItems(node.template, binding: node.props.itemsBinding)
            }
        case .list(let node):
            LazyVStack(spacing: 20) {
                templateItems(node.template, binding: node.props.itemsBinding)
            }
        case .button(let node):
            SDUIButton(label: scope.string(node.props.label), style: node.props.style,
                       action: node.action, scope: scope)
        case .spacer(let node):
            Color.clear.frame(width: node.props.size, height: node.props.size)
        case .unknown(let type, let id):
            UnknownComponentView(type: type, id: id)
        }
    }

    private func children(_ components: [Component]) -> some View {
        ForEach(Array(components.enumerated()), id: \.offset) { _, child in
            ComponentView(child, scope: scope)
        }
    }

    /// Stamps out `template` once per element of the array at `binding`.
    @ViewBuilder
    private func templateItems(_ template: Component, binding: String) -> some View {
        if let items = scope.resolve(binding)?.arrayValue {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                ComponentView(template, scope: scope.with(item: item))
            }
        } else {
            let _ = Logger.sdui.warning("itemsBinding '\(binding, privacy: .public)' is not an array")
        }
    }
}

/// Wraps content in a plain button when there is an action to run.
private struct Tappable<Content: View>: View {
    let action: Action?
    let scope: BindingScope
    @ViewBuilder let content: Content
    @Environment(\.sduiActionHandler) private var handle

    var body: some View {
        if let action {
            Button { handle(action.resolved(in: scope)) } label: { content.contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

private struct SDUIText: View {
    let text: String
    let style: String?

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(style == "caption" ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var font: Font {
        switch style {
        case "title": return .largeTitle.bold()
        case "headline": return .headline
        case "caption": return .caption
        default: return .body
        }
    }
}

struct SDUIImage: View {
    let url: String
    var alt: String?
    var aspectRatio: Double?
    @Environment(\.sduiLocalImageProvider) private var localImage

    var body: some View {
        Color.secondary.opacity(0.12)
            .aspectRatio(aspectRatio.map { CGFloat($0) }, contentMode: .fit)
            .overlay { content.scaledToFill() }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel(alt ?? "")
    }

    @ViewBuilder
    private var content: some View {
        if let parsed = URL(string: url), ["http", "https"].contains(parsed.scheme) {
            AsyncImage(url: parsed) { phase in
                phase.image?.resizable()
            }
        } else if let parsed = URL(string: url), let image = localImage(parsed) {
            image.resizable()
        }
    }
}

private struct SDUICard: View {
    let imageURL: String?
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL {
                SDUIImage(url: imageURL, aspectRatio: 1)
                    .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 14, topTrailing: 14)))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(2)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.quaternary))
        .accessibilityElement(children: .combine)
    }
}

private struct SDUIButton: View {
    let label: String
    let style: String?
    let action: Action
    let scope: BindingScope
    @Environment(\.sduiActionHandler) private var handle

    var body: some View {
        if style == "secondary" {
            Button(label, action: run).buttonStyle(.bordered)
        } else {
            Button(label, action: run).buttonStyle(.borderedProminent)
        }
    }

    private func run() {
        handle(action.resolved(in: scope))
    }
}

/// Placeholder for a component this client can't render. Visible on purpose:
/// a silent gap would hide a schema mismatch.
struct UnknownComponentView: View {
    let type: String
    let id: String

    var body: some View {
        Text("Unsupported component: \(type)")
            .font(.caption.monospaced())
            .foregroundStyle(.orange)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.orange, style: StrokeStyle(lineWidth: 1, dash: [4])))
            .onAppear {
                Logger.sdui.warning("Unknown component type '\(type, privacy: .public)' (id '\(id, privacy: .public)')")
            }
    }
}
