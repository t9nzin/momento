import Foundation
import SwiftData

@Model
final class Memento {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var imageFilename: String

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, imageFilename: String) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.imageFilename = imageFilename
    }
}
