import SwiftUI
import AVFoundation
import UIKit

struct CameraView: UIViewRepresentable {
    let controller: CameraController
    let onTap: (CGPoint, CGSize) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = controller.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.onTap = onTap
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var onTap: ((CGPoint, CGSize) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            addGestureRecognizer(tap)
        }
        required init?(coder: NSCoder) { fatalError() }

        @objc private func handleTap(_ g: UITapGestureRecognizer) {
            let point = g.location(in: self)
            onTap?(point, bounds.size)
        }
    }
}
