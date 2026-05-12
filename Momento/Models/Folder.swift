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

    @Relationship(deleteRule: .cascade, inverse: \Memento.folder)
    var stamps: [Memento] = []

    init(
        id: UUID = UUID(),
        name: String,
        order: Int,
        leftStickerAsset: String,
        rightStickerAsset: String,
        peekPhotoAssets: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.leftStickerAsset = leftStickerAsset
        self.rightStickerAsset = rightStickerAsset
        self.peekPhotoAssets = peekPhotoAssets
        self.createdAt = createdAt
    }
}
