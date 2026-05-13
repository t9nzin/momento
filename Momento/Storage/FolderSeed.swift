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
        let stamps: [String]
    }

    private static let seeds: [SeedFolder] = [
        SeedFolder(name: "Italy 2025",
                   leftSticker: "ItalyFlag",
                   rightSticker: "Lemon",
                   peekPhotos: ["it1", "it2", "it3"],
                   stamps: ["italyStamp1", "italyStamp2", "italyStamp3", "italyStamp4"]),
        SeedFolder(name: "Japan 2024",
                   leftSticker: "FlagSticker",
                   rightSticker: "JapanDecor",
                   peekPhotos: [],
                   stamps: defaultStamps),
        SeedFolder(name: "Amsterdam 2024",
                   leftSticker: "Tulip",
                   rightSticker: "DutchFlag",
                   peekPhotos: ["am1", "am2", "am3"],
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
                guard currentAssets != seed.stamps else { continue }
                let userStamps = folder.stamps.filter { $0.assetName == nil }
                let seededStamps = folder.stamps.filter { $0.assetName != nil }
                for stamp in seededStamps { context.delete(stamp) }
                folder.stamps = userStamps
                for asset in seed.stamps {
                    let stamp = Memento(name: asset, imageFilename: "", assetName: asset, folder: folder)
                    context.insert(stamp)
                    folder.stamps.append(stamp)
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
