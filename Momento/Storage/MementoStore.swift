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

    /// Writes a PNG (with alpha) to disk and inserts a Memento row.
    @MainActor
    static func save(cgImage: CGImage, name: String, into context: ModelContext) throws -> Memento {
        let filename = "\(UUID().uuidString).png"
        let url = try mementosDirectory().appendingPathComponent(filename)
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.pngData() else { throw StorageError.pngEncodingFailed }
        try data.write(to: url, options: .atomic)

        let memento = Memento(name: name, imageFilename: filename)
        context.insert(memento)
        try context.save()
        return memento
    }
}
