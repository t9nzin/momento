import Foundation

/// Arbitrary JSON, used for a screen's `data` since its shape varies per screen.
public enum JSONValue: Equatable, Sendable, Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public subscript(key: String) -> JSONValue? {
        guard case .object(let object) = self else { return nil }
        return object[key]
    }

    public var arrayValue: [JSONValue]? {
        guard case .array(let array) = self else { return nil }
        return array
    }

    /// How the value reads when interpolated into text. Whole numbers drop the
    /// decimal so `2016` doesn't render as `2016.0`.
    public var displayString: String {
        switch self {
        case .string(let value): return value
        case .number(let value):
            return value.rounded() == value && abs(value) < 1e15 ? String(Int64(value)) : String(value)
        case .bool(let value): return String(value)
        case .null: return ""
        case .object, .array: return ""
        }
    }

    /// Returns an object with `other`'s keys replacing this one's.
    public func merging(_ other: [String: JSONValue]) -> JSONValue {
        guard case .object(var object) = self else { return .object(other) }
        object.merge(other) { _, new in new }
        return .object(object)
    }
}
