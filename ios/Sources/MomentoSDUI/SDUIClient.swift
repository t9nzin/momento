import Foundation

/// Fetches screens and runs `request` actions against the SDUI server.
public struct SDUIClient: Sendable {
    public var baseURL: URL
    public var userId: String
    public var supportedComponents: [String]
    private let session: URLSession

    public init(baseURL: URL, userId: String, supportedComponents: [String] = Component.supportedTypes,
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.userId = userId
        self.supportedComponents = supportedComponents
        self.session = session
    }

    /// The context headers sent with every request.
    public var headers: [String: String] {
        [
            "X-User-Id": userId,
            "X-Platform": "ios",
            "X-Schema-Version": String(Screen.schemaVersion),
            "X-Supported-Components": supportedComponents.joined(separator: ","),
        ]
    }

    public func screenRequest(_ screenId: String, params: [String: String] = [:]) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: "api/screens/\(screenId)"),
                                       resolvingAgainstBaseURL: false)!
        if !params.isEmpty {
            components.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return request(url: components.url!, method: "GET")
    }

    public func screen(_ screenId: String, params: [String: String] = [:]) async throws -> Screen {
        let (data, response) = try await session.data(for: screenRequest(screenId, params: params))
        try Self.check(response)
        return try JSONDecoder().decode(Screen.self, from: data)
    }

    /// Runs a `request` action's call. `path` is absolute on the server, e.g. `/api/items/1/favorite`.
    public func send(method: String, path: String) async throws {
        let (_, response) = try await session.data(for: request(url: baseURL.appending(path: path), method: method))
        try Self.check(response)
    }

    private func request(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
