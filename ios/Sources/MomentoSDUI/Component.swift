import Foundation
import OSLog

/// A node in a screen's component tree, mirroring schema v1.
///
/// Decoding never fails on an unrecognised or malformed component: it becomes
/// `.unknown`, which renders a visible placeholder while the rest of the screen
/// still works.
public indirect enum Component: Equatable, Sendable, Decodable, Identifiable {
    case column(StackNode)
    case row(StackNode)
    case text(TextNode)
    case image(ImageNode)
    case card(CardNode)
    case grid(GridNode)
    case list(ListNode)
    case button(ButtonNode)
    case spacer(SpacerNode)
    case unknown(type: String, id: String)

    /// Every type this renderer draws natively; sent as `X-Supported-Components`.
    public static let supportedTypes = ["column", "row", "text", "image", "card", "grid", "list", "button", "spacer"]

    private enum CodingKeys: String, CodingKey {
        case type, id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let id = (try? container.decode(String.self, forKey: .id)) ?? ""
        do {
            switch type {
            case "column": self = .column(try StackNode(from: decoder))
            case "row": self = .row(try StackNode(from: decoder))
            case "text": self = .text(try TextNode(from: decoder))
            case "image": self = .image(try ImageNode(from: decoder))
            case "card": self = .card(try CardNode(from: decoder))
            case "grid": self = .grid(try GridNode(from: decoder))
            case "list": self = .list(try ListNode(from: decoder))
            case "button": self = .button(try ButtonNode(from: decoder))
            case "spacer": self = .spacer(try SpacerNode(from: decoder))
            default: self = .unknown(type: type, id: id)
            }
        } catch {
            Logger.sdui.warning("Could not decode \(type, privacy: .public) '\(id, privacy: .public)': \(error)")
            self = .unknown(type: type, id: id)
        }
    }

    public var id: String {
        switch self {
        case .column(let node), .row(let node): return node.id
        case .text(let node): return node.id
        case .image(let node): return node.id
        case .card(let node): return node.id
        case .grid(let node): return node.id
        case .list(let node): return node.id
        case .button(let node): return node.id
        case .spacer(let node): return node.id
        case .unknown(_, let id): return id
        }
    }
}

public struct StackNode: Equatable, Sendable, Decodable {
    public struct Props: Equatable, Sendable, Decodable {
        public var spacing: Double?
    }

    public var id: String
    public var props: Props?
    public var children: [Component]
    public var action: Action?
}

public struct TextNode: Equatable, Sendable, Decodable {
    public struct Props: Equatable, Sendable, Decodable {
        public var text: String
        /// `title`, `headline`, `body` or `caption`.
        public var style: String?
    }

    public var id: String
    public var props: Props
}

public struct ImageNode: Equatable, Sendable, Decodable {
    public struct Props: Equatable, Sendable, Decodable {
        public var url: String
        public var alt: String?
        public var aspectRatio: Double?
    }

    public var id: String
    public var props: Props
}

public struct CardNode: Equatable, Sendable, Decodable {
    public struct Props: Equatable, Sendable, Decodable {
        public var imageUrl: String?
        public var title: String
        public var subtitle: String?
    }

    public var id: String
    public var props: Props
    public var action: Action?
}

public struct GridNode: Equatable, Sendable, Decodable {
    public struct Props: Equatable, Sendable, Decodable {
        public var columns: Int
        public var itemsBinding: String
    }

    public var id: String
    public var props: Props
    public var template: Component
}

public struct ListNode: Equatable, Sendable, Decodable {
    public struct Props: Equatable, Sendable, Decodable {
        public var itemsBinding: String
    }

    public var id: String
    public var props: Props
    public var template: Component
}

public struct ButtonNode: Equatable, Sendable, Decodable {
    public struct Props: Equatable, Sendable, Decodable {
        public var label: String
        /// `primary` or `secondary`.
        public var style: String?
    }

    public var id: String
    public var props: Props
    public var action: Action
}

public struct SpacerNode: Equatable, Sendable, Decodable {
    public struct Props: Equatable, Sendable, Decodable {
        public var size: Double
    }

    public var id: String
    public var props: Props
}

extension Logger {
    static let sdui = Logger(subsystem: "com.tenzin.momento", category: "sdui")
}
