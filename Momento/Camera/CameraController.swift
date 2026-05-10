import AVFoundation
import CoreVideo
import UIKit

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "momento.camera.session")
    private let frameQueue = DispatchQueue(label: "momento.camera.frames")

    private var latestPixelBuffer: CVPixelBuffer?
    private let bufferLock = NSLock()

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func currentPixelBuffer() -> CVPixelBuffer? {
        bufferLock.lock(); defer { bufferLock.unlock() }
        return latestPixelBuffer
    }

    private var didConfigure = false
    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        session.beginConfiguration()
        session.sessionPreset = .photo

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        if let conn = videoOutput.connection(with: .video), conn.isVideoOrientationSupported {
            conn.videoOrientation = .portrait
        }

        session.commitConfiguration()
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        bufferLock.lock()
        latestPixelBuffer = buffer
        bufferLock.unlock()
    }
}
