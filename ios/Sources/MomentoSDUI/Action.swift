import Foundation

/// Something the client does when the user taps a component.
public enum Action: Equatable, Sendable, Decodable {
    /// Open another server-driven screen.
    case navigate(screenId: String, params: [String: String])
    /// Call the API, then optionally re-fetch the current screen.
    case request(method: String, path: String, refresh: Bool)
    /// An action type this client doesn't know. Tapping it does nothing.
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey {
        case type, screenId, params, method, path, refresh
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "navigate":
            self = .navigate(
                screenId: try container.decode(String.self, forKey: .screenId),
                params: try container.decodeIfPresent([String: String].self, forKey: .params) ?? [:])
        case "request":
            self = .request(
                method: try container.decode(String.self, forKey: .method),
                path: try container.decode(String.self, forKey: .path),
                refresh: try container.decodeIfPresent(Bool.self, forKey: .refresh) ?? false)
        default:
            self = .unknown(type: type)
        }
    }

    /// The action with every `{{binding}}` filled in from `scope`.
    public func resolved(in scope: BindingScope) -> Action {
        switch self {
        case .navigate(let screenId, let params):
            return .navigate(screenId: scope.string(screenId), params: params.mapValues(scope.string))
        case .request(let method, let path, let refresh):
            return .request(method: method, path: scope.string(path), refresh: refresh)
        case .unknown:
            return self
        }
    }
}
