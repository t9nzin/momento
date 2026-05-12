import Foundation
import SwiftData

enum FolderSeed {
    private static let defaultStamps: [String] = [
        "cardNoProblem",
        "cardKassian",
        "cardLandscape",
        "cardText"
    ]

    private struct SeedFolder {
        let name: String
        let leftSticker: String
        let rightSticker: String
        let peekPhotos: [String]
    }

    private static let seeds: [SeedFolder] = [
        SeedFolder(name: "Italy 2025",
                   leftSticker: "ItalyFlag",
                   rightSticker: "Lemon",
                   peekPhotos: ["it1", "it2", "it3"]),
        SeedFolder(name: "Japan 2024",
                   leftSticker: "FlagSticker",
                   rightSticker: "JapanDecor",
                   peekPhotos: []),
        SeedFolder(name: "Amsterdam 2024",
                   leftSticker: "Tulip",
                   rightSticker: "DutchFlag",
                   peekPhotos: ["am1", "am2", "am3"])
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Folder>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        for (idx, seed) in seeds.enumerated() {
            let folder = Folder(
                name: seed.name,
                order: idx,
                leftStickerAsset: seed.leftSticker,
                rightStickerAsset: seed.rightSticker,
                peekPhotoAssets: seed.peekPhotos
            )
            context.insert(folder)

            for asset in defaultStamps {
                let stamp = Memento(
                    name: asset,
                    imageFilename: "",
                    assetName: asset,
                    folder: folder
                )
                context.insert(stamp)
                folder.stamps.append(stamp)
            }
        }
        try? context.save()
    }
}
