import Foundation

/// Settings for talking to the server-driven UI backend.
enum SDUIConfig {
    /// From `SDUIBaseURL` in Info.plist. localhost works in the simulator; on a
    /// device, point it at your Mac's LAN address.
    static var baseURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "SDUIBaseURL") as? String
        return configured.flatMap(URL.init(string:)) ?? URL(string: "http://localhost:8080")!
    }

    /// A random id generated once per install, so the server buckets this
    /// device into the same layout variant every launch.
    static var userId: String {
        let key = "sdui.userId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let id = "ios-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    /// Set by the `-SDUIGallery YES` launch argument (see the Momento scheme).
    static var launchIntoGallery: Bool {
        UserDefaults.standard.bool(forKey: "SDUIGallery")
    }
}
