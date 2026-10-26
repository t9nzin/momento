import Foundation

public struct Screen: Equatable, Sendable, Decodable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var screenId: String
    public var title: String
    public var data: JSONValue
    public var root: Component
}
