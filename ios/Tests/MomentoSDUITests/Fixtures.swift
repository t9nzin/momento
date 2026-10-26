import Foundation
@testable import MomentoSDUI

/// Loads the shared fixtures in /schema/fixtures, the same files the server and web tests use.
enum Fixtures {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../../schema/fixtures")
        .standardized

    static func screen(_ name: String) throws -> Screen {
        try JSONDecoder().decode(Screen.self, from: Data(contentsOf: directory.appending(path: name)))
    }
}
