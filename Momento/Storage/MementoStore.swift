import Foundation
import ImageIO
import UIKit
import SwiftData

enum StorageError: Error {
    case pngEncodingFailed
}

struct MementoStore {
    private static let displayMaxPixelSize: CGFloat = 720
    private static let storageMaxPixelSize: CGFloat = 900

    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 120
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

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
        let key = cacheKey(for: filename)
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let dir = try? mementosDirectory() else { return nil }
        let url = dir.appendingPathComponent(filename)
        guard let image = downsampledImage(at: url, maxPixelSize: displayMaxPixelSize)
                ?? UIImage(contentsOfFile: url.path) else {
            return nil
        }
        imageCache.setObject(image, forKey: key, cost: cacheCost(for: image))
        return image
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
        let uiImage = resizedForStorage(cgImage: cgImage, maxPixelSize: storageMaxPixelSize)
        guard let data = uiImage.pngData() else { throw StorageError.pngEncodingFailed }
        try data.write(to: url, options: .atomic)
        imageCache.setObject(uiImage, forKey: cacheKey(for: filename), cost: cacheCost(for: uiImage))

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

    private static func cacheKey(for filename: String) -> NSString {
        "file:\(filename)" as NSString
    }

    private static func cacheCost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return cgImage.width * cgImage.height * 4
    }

    private static func downsampledImage(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }

    private static func resizedForStorage(cgImage: CGImage, maxPixelSize: CGFloat) -> UIImage {
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let maxDimension = max(pixelWidth, pixelHeight)
        let source = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        guard maxDimension > maxPixelSize else { return source }

        let scale = maxPixelSize / maxDimension
        let targetSize = CGSize(width: pixelWidth * scale, height: pixelHeight * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
