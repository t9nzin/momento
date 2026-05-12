import Foundation
import SwiftData

@Model
final class Memento {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    /// On-disk PNG filename in the documents/mementos directory. Empty when the
    /// stamp is sourced from a bundled asset instead.
    var imageFilename: String
    /// When set, the stamp's image lives in the asset catalog rather than on
    /// disk. Used for seeded demo content.
    var assetName: String?
    /// Location captured at punch time. nil for seeded data or when permission
    /// was denied / no fix was available.
    var latitude: Double?
    var longitude: Double?
    var folder: Folder?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        imageFilename: String = "",
        assetName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        folder: Folder? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.imageFilename = imageFilename
        self.assetName = assetName
        self.latitude = latitude
        self.longitude = longitude
        self.folder = folder
    }
}
