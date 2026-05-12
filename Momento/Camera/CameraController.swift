import AVFoundation
import UIKit
import SwiftUI

/// AVCaptureSession wrapper that exposes a live preview and one-shot photo
/// capture. Modeled after the proven Stampable approach: uses
/// `AVCapturePhotoOutput` rather than a continuous frame stream, so the
/// preview comes up the moment the session is running.
final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "momento.camera.session")
    private var captureContinuation: CheckedContinuation<UIImage, Error>?

    @Published var isAuthorized: Bool = false
    @Published var isConfigured: Bool = false
    @Published var hasCaptureDevice: Bool = false

    /// Set by `CameraView` once the layer is attached. Not @Published — this
    /// is used at capture time only and shouldn't drive SwiftUI re-renders.
    var previewLayer: AVCaptureVideoPreviewLayer?

    enum CameraError: Error {
        case notAuthorized
        case configurationFailed
        case captureFailed
        case noConnection
        case decodeFailed
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// One-shot entry point: resolves authorization then configures + starts
    /// the session if allowed. Idempotent — safe to call multiple times.
    func requestAuthorizationAndStart() {
        if Self.isSimulator {
            isAuthorized = false
            hasCaptureDevice = false
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.configureAndStart() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    /// Idempotent start (assuming authorization has already been resolved).
    func start() {
        if Self.isSimulator { return }
        guard isAuthorized else { return }
        configureAndStart()
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configure()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.hasCaptureDevice = false }
            return
        }
        session.addInput(input)

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.hasCaptureDevice = false }
            return
        }

        session.commitConfiguration()
        DispatchQueue.main.async {
            self.isConfigured = true
            self.hasCaptureDevice = true
        }
    }

    func capturePhoto() async throws -> UIImage {
        if Self.isSimulator { throw CameraError.noConnection }
        guard let connection = photoOutput.connection(with: .video),
              connection.isActive, connection.isEnabled else {
            throw CameraError.noConnection
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UIImage, Error>) in
            self.captureContinuation = cont
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            queue.async { [photoOutput] in
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            captureContinuation?.resume(throwing: error)
            captureContinuation = nil
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            captureContinuation?.resume(throwing: CameraError.decodeFailed)
            captureContinuation = nil
            return
        }
        captureContinuation?.resume(returning: Self.normalizedUp(image))
        captureContinuation = nil
    }

    /// Re-draws the image with `.up` orientation so the backing CGImage's
    /// pixel rect matches the visual rect — required before cropping with
    /// `cgImage.cropping(to:)`.
    private static func normalizedUp(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
