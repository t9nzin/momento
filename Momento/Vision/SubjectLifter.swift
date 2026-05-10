import Vision
import CoreImage
import UIKit

enum LiftError: Error {
    case requestFailed
    case noInstanceAtPoint
    case maskingFailed
}

struct SubjectLifter {
    /// Lifts the subject under `tapPointInImage` (image-space coords, origin top-left)
    /// from `pixelBuffer`. Returns a cropped CGImage with transparent background.
    static func lift(from pixelBuffer: CVPixelBuffer,
                     tapPointInImage: CGPoint) async throws -> CGImage {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        let request = VNGenerateForegroundInstanceMaskRequest()

        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    guard let observation = request.results?.first else {
                        cont.resume(throwing: LiftError.requestFailed); return
                    }

                    let imgWidth = CVPixelBufferGetWidth(pixelBuffer)
                    let imgHeight = CVPixelBufferGetHeight(pixelBuffer)

                    let instanceIndex = instanceContaining(point: tapPointInImage,
                                                           in: observation,
                                                           imageWidth: imgWidth,
                                                           imageHeight: imgHeight)

                    let instances: IndexSet
                    if let idx = instanceIndex {
                        instances = IndexSet(integer: idx)
                    } else if !observation.allInstances.isEmpty {
                        // Fallback: lift all foreground if tap missed
                        instances = observation.allInstances
                    } else {
                        cont.resume(throwing: LiftError.noInstanceAtPoint); return
                    }

                    let masked = try observation.generateMaskedImage(
                        ofInstances: instances,
                        from: handler,
                        croppedToInstancesExtent: true
                    )
                    let ciImage = CIImage(cvPixelBuffer: masked)
                    let context = CIContext()
                    guard let cg = context.createCGImage(ciImage, from: ciImage.extent) else {
                        cont.resume(throwing: LiftError.maskingFailed); return
                    }
                    cont.resume(returning: cg)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private static func instanceContaining(point: CGPoint,
                                           in observation: VNInstanceMaskObservation,
                                           imageWidth: Int,
                                           imageHeight: Int) -> Int? {
        // Try each instance: render its mask and sample the tap pixel.
        for idx in observation.allInstances {
            guard let maskBuffer = try? observation.generateScaledMaskForImage(
                forInstances: IndexSet(integer: idx),
                from: VNImageRequestHandler(cvPixelBuffer: dummyBuffer(width: imageWidth, height: imageHeight),
                                            orientation: .up)
            ) else { continue }
            if sample(maskBuffer: maskBuffer, at: point) > 0.5 {
                return idx
            }
        }
        return nil
    }

    private static func dummyBuffer(width: Int, height: Int) -> CVPixelBuffer {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &pb)
        return pb!
    }

    private static func sample(maskBuffer: CVPixelBuffer, at point: CGPoint) -> Float {
        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }
        let w = CVPixelBufferGetWidth(maskBuffer)
        let h = CVPixelBufferGetHeight(maskBuffer)
        let x = max(0, min(w - 1, Int(point.x)))
        let y = max(0, min(h - 1, Int(point.y)))
        let bpr = CVPixelBufferGetBytesPerRow(maskBuffer)
        guard let base = CVPixelBufferGetBaseAddress(maskBuffer) else { return 0 }
        let pixel = base.advanced(by: y * bpr + x).assumingMemoryBound(to: UInt8.self)
        return Float(pixel.pointee) / 255.0
    }
}
