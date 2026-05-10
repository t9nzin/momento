import SwiftUI
import AVFoundation
import SwiftData

struct CaptureScreen: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var camera = CameraController()
    @State private var liftedImage: UIImage?
    @State private var pendingName: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraView(controller: camera) { point, viewSize in
                handleTap(point: point, viewSize: viewSize)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                Text(isProcessing ? "Lifting…" : "Tap anything to collect it")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            requestCameraAccess { granted in
                if granted { camera.start() }
            }
        }
        .onDisappear { camera.stop() }
        .sheet(item: Binding(
            get: { liftedImage.map { LiftedWrapper(image: $0) } },
            set: { if $0 == nil { liftedImage = nil; pendingName = "" } }
        )) { wrap in
            SavePreviewSheet(image: wrap.image, name: $pendingName) {
                save(image: wrap.image)
            } onRetake: {
                liftedImage = nil
                pendingName = ""
            }
        }
        .alert("Couldn't lift subject",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func handleTap(point: CGPoint, viewSize: CGSize) {
        guard !isProcessing, let buffer = camera.currentPixelBuffer() else { return }
        isProcessing = true

        let imgW = CGFloat(CVPixelBufferGetWidth(buffer))
        let imgH = CGFloat(CVPixelBufferGetHeight(buffer))
        let pointInImage = mapTapToImage(point: point,
                                         viewSize: viewSize,
                                         imageSize: CGSize(width: imgW, height: imgH))

        Task {
            do {
                let cg = try await SubjectLifter.lift(from: buffer, tapPointInImage: pointInImage)
                await MainActor.run {
                    liftedImage = UIImage(cgImage: cg)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Try tapping more directly on the object."
                    isProcessing = false
                }
            }
        }
    }

    /// Maps a tap in the .resizeAspectFill preview to the underlying image coordinates.
    private func mapTapToImage(point: CGPoint, viewSize: CGSize, imageSize: CGSize) -> CGPoint {
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let displayedW = imageSize.width * scale
        let displayedH = imageSize.height * scale
        let offsetX = (displayedW - viewSize.width) / 2
        let offsetY = (displayedH - viewSize.height) / 2
        let x = (point.x + offsetX) / scale
        let y = (point.y + offsetY) / scale
        return CGPoint(x: x, y: y)
    }

    private func save(image: UIImage) {
        guard let cg = image.cgImage else { return }
        let name = pendingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? "Memento" : name
        do {
            _ = try MementoStore.save(cgImage: cg, name: finalName, into: modelContext)
            liftedImage = nil
            pendingName = ""
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    private func requestCameraAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { completion(ok) }
            }
        default: completion(false)
        }
    }
}

private struct LiftedWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct SavePreviewSheet: View {
    let image: UIImage
    @Binding var name: String
    let onSave: () -> Void
    let onRetake: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)

            TextField("Name this memento", text: $name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            HStack {
                Button("Retake", role: .cancel, action: onRetake)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 30)
        .presentationDetents([.medium, .large])
    }
}
