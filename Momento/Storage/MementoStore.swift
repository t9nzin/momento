import Foundation
import UIKit
import SwiftData

enum StorageError: Error {
    case pngEncodingFailed
}

struct MementoStore {
    static func mementosDirectory() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = docs.appendingPathComponent("mementos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func loadImage(filename: String) -> UIImage? {
        guard let dir = try? mementosDirectory() else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(filename).path)
    }

    /// Resolves a Memento to a UIImage, preferring its bundled `assetName` and
    /// falling back to the on-disk PNG referenced by `imageFilename`.
    static func image(for memento: Memento) -> UIImage? {
        if let asset = memento.assetName, let img = UIImage(named: asset) { return img }
        if !memento.imageFilename.isEmpty {
            return loadImage(filename: memento.imageFilename)
        }
        return nil
    }

    /// Writes a PNG (with alpha) to disk and inserts a Memento row, optionally
    /// attached to a folder and tagged with a coordinate.
    @MainActor
    static func save(cgImage: CGImage,
                     name: String,
                     in folder: Folder? = nil,
                     latitude: Double? = nil,
                     longitude: Double? = nil,
                     context: ModelContext) throws -> Memento {
        let filename = "\(UUID().uuidString).png"
        let url = try mementosDirectory().appendingPathComponent(filename)
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.pngData() else { throw StorageError.pngEncodingFailed }
        try data.write(to: url, options: .atomic)

        let memento = Memento(
            name: name,
            imageFilename: filename,
            latitude: latitude,
            longitude: longitude,
            folder: folder
        )
        context.insert(memento)
        folder?.stamps.append(memento)
        try context.save()
        return memento
    }
}
