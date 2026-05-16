import Foundation
import SwiftData

@Model
final class Folder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var order: Int
    var leftStickerAsset: String
    var rightStickerAsset: String
    /// Up to three asset names used for the closed-folder peek photos.
    var peekPhotoAssets: [String]
    /// JSON-encoded user-placed cover stickers for this folder.
    var placedStickerData: Data?

    @Relationship(deleteRule: .cascade, inverse: \Memento.folder)
    var stamps: [Memento] = []

    init(
        id: UUID = UUID(),
        name: String,
        order: Int,
        leftStickerAsset: String,
        rightStickerAsset: String,
        peekPhotoAssets: [String] = [],
        placedStickerData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.leftStickerAsset = leftStickerAsset
        self.rightStickerAsset = rightStickerAsset
        self.peekPhotoAssets = peekPhotoAssets
        self.placedStickerData = placedStickerData
        self.createdAt = createdAt
    }
}

extension Folder {
    var placedStickers: [PlacedSticker] {
        get {
            guard let placedStickerData else { return [] }
            return (try? JSONDecoder().decode([PlacedSticker].self, from: placedStickerData)) ?? []
        }
        set {
            placedStickerData = try? JSONEncoder().encode(newValue)
        }
    }
}
