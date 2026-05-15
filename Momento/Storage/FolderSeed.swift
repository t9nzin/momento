import Foundation
import SwiftData

enum FolderSeed {
    private struct SeedFolder {
        let name: String
        let leftSticker: String
        let rightSticker: String
        let stamps: [String]
        var peekPhotos: [String] { Array(stamps.prefix(2)) }
    }

    private static let seeds: [SeedFolder] = [
        SeedFolder(name: "Italy 2025",
                   leftSticker: "ItalyFlag",
                   rightSticker: "Lemon",
                   stamps: ["italyStamp1", "italyStamp2", "italyStamp3", "italyStamp4"]),
        SeedFolder(name: "Japan 2024",
                   leftSticker: "FlagSticker",
                   rightSticker: "JapanDecor",
                   stamps: ["japanStamp1", "japanStamp2", "japanStamp3", "japanStamp4"]),
        SeedFolder(name: "Amsterdam 2024",
                   leftSticker: "Tulip",
                   rightSticker: "DutchFlag",
                   stamps: ["amsStamp1", "amsStamp2", "amsStamp3", "amsStamp4"])
    ]

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Folder>()
        let existing = (try? context.fetch(descriptor)) ?? []

        if existing.isEmpty {
            for (idx, seed) in seeds.enumerated() {
                insert(seed: seed, order: idx, context: context)
            }
        } else {
            for folder in existing {
                guard let seed = seeds.first(where: { $0.name == folder.name }) else { continue }
                let currentAssets = folder.stamps.compactMap { $0.assetName }
                let needsStampRefresh = currentAssets != seed.stamps || folder.stamps.count != seed.stamps.count
                let needsPeekRefresh = folder.peekPhotoAssets != seed.peekPhotos

                if needsStampRefresh {
                    for stamp in folder.stamps { context.delete(stamp) }
                    folder.stamps = []
                    for asset in seed.stamps {
                        let stamp = Memento(name: asset, imageFilename: "", assetName: asset, folder: folder)
                        context.insert(stamp)
                        folder.stamps.append(stamp)
                    }
                }
                if needsPeekRefresh {
                    folder.peekPhotoAssets = seed.peekPhotos
                }
            }
        }
        try? context.save()
    }

    @MainActor
    private static func insert(seed: SeedFolder, order: Int, context: ModelContext) {
        let folder = Folder(
            name: seed.name,
            order: order,
            leftStickerAsset: seed.leftSticker,
            rightStickerAsset: seed.rightSticker,
            peekPhotoAssets: seed.peekPhotos
        )
        context.insert(folder)
        for asset in seed.stamps {
            let stamp = Memento(name: asset, imageFilename: "", assetName: asset, folder: folder)
            context.insert(stamp)
            folder.stamps.append(stamp)
        }
    }
}
