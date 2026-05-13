import SwiftUI
import SwiftData
import AVFoundation
import CoreImage
import CoreLocation
import PhotosUI
import UIKit

struct StampPunchView: View {
    let folder: Folder
    @ObservedObject var camera: CameraController

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case live, lifting, review }

    @State private var phase: Phase = .live
    @State private var stampImage: UIImage?
    @State private var stampName: String = ""
    @State private var pressAmount: CGFloat = 0      // 0 = idle, 1 = peak compression
    @State private var liftProgress: CGFloat = 0     // 0 = in cutter, 1 = lifted out
    @State private var sceneFade: CGFloat = 0        // 0 = camera bg, 1 = neutral bg
    @State private var reviewTilt: Double = 0
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoLibraryImage: UIImage?
    @State private var cutterPressTask: Task<Void, Never>?

    // Draggable cutter
    @State private var cutterOffset: CGSize = .zero
    @State private var cutterDragDelta: CGSize = .zero
    @State private var isDraggingCutter: Bool = false
    private let dragTapThreshold: CGFloat = 8

    /// Coordinate snapshotted at punch time so the eventual save records where
    /// the stamp was actually punched, not where the user happened to be when
    /// they hit Save.
    @State private var pendingCoordinate: CLLocationCoordinate2D?

    // Inner perforated region measured against the stamp_cutter.png frame.
    private let cutterAspect: CGFloat = 1024.0 / 1536.0
    private let cutterWidthFraction: CGFloat = 0.86
    private let cutterVerticalCenterFraction: CGFloat = 0.46
    private let innerWidthRatio: CGFloat = 0.71   // of cutter width
    private let innerHeightRatio: CGFloat = 0.535 // of cutter height
    private let innerYOffsetRatio: CGFloat = -0.03 // of cutter height (negative = up)

    var body: some View {
        ZStack {
            cameraBackground

            GeometryReader { geo in
                stampStage(in: geo.size)
            }

            reviewNameField

            topBar
            bottomBar
        }
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .ignoresSafeArea()
        .onAppear {
            startCamera()
            LocationProvider.shared.start()
        }
        .onDisappear {
            cancelCutterPress()
            camera.stop()
            LocationProvider.shared.stop()
        }
        .alert("Couldn't capture",
               isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
               )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: selectedPhotoItem) { _, item in
            loadPhotoLibraryStamp(from: item)
        }
    }

    private var reviewNameField: some View {
        VStack {
            if phase == .review {
                TextField("Name", text: $stampName)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.top, 130)
                    .transition(.opacity)
            }
            Spacer()
        }
    }

    // MARK: - Camera background

    private var cameraBackground: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.96, green: 0.96, blue: 0.97)
                if let photoLibraryImage {
                    Image(uiImage: photoLibraryImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(1.0 - Double(sceneFade))
                        .blur(radius: Double(sceneFade) * 18)
                } else if camera.isAuthorized && camera.hasCaptureDevice {
                    CameraView(controller: camera) { _, _ in }
                        .opacity(1.0 - Double(sceneFade))
                        .blur(radius: Double(sceneFade) * 18)
                } else if CameraController.isSimulator {
                    cameraUnavailableHint(text: "Simulator — tap to punch with a placeholder image.")
                } else if !camera.isAuthorized {
                    cameraUnavailableHint(text: "Camera access needed. Enable it in Settings.")
                }
            }
        }
    }

    private func cameraUnavailableHint(text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.black.opacity(0.35))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Color.black.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .opacity(1.0 - Double(sceneFade))
    }

    // MARK: - Stamp + cutter stage

    private func stampStage(in size: CGSize) -> some View {
        let cutterW = size.width * cutterWidthFraction
        let cutterH = cutterW / cutterAspect
        let baseCenter = CGPoint(x: size.width / 2, y: size.height * cutterVerticalCenterFraction)
        let liveOffset = CGSize(
            width: cutterOffset.width + cutterDragDelta.width,
            height: cutterOffset.height + cutterDragDelta.height
        )
        let cutterCenter = CGPoint(
            x: baseCenter.x + liveOffset.width,
            y: baseCenter.y + liveOffset.height
        )
        let innerW = cutterW * innerWidthRatio
        let innerH = cutterH * innerHeightRatio
        let innerCenter = CGPoint(x: cutterCenter.x,
                                  y: cutterCenter.y + cutterH * innerYOffsetRatio)
        let reviewCenter = CGPoint(x: size.width / 2,
                                   y: size.height * cutterVerticalCenterFraction - 10)

        return ZStack {
            // Captured stamp — rises out of the cutter as liftProgress goes 0→1.
            // In the review phase it returns to the screen center regardless
            // of where the cutter was when punched.
            if let img = stampImage {
                let stampPos: CGPoint = {
                    if phase == .review { return reviewCenter }
                    return CGPoint(x: innerCenter.x,
                                   y: innerCenter.y - liftProgress * 46)
                }()
                stampView(image: img, width: innerW, height: innerH)
                    .rotationEffect(.degrees(phase == .review ? reviewTilt : 0))
                    .scaleEffect(phase == .review ? 1.18 : (1.0 + liftProgress * 0.04))
                    .position(stampPos)
                    .zIndex(2)
            }

            // The cutter chassis — sits over the camera, compresses on press,
            // fades during the review phase.
            Image("StampCutter")
                .resizable()
                .scaledToFit()
                .frame(width: cutterW)
                .position(cutterCenter)
                .scaleEffect(1.0 - pressAmount * 0.035 + (isDraggingCutter ? 0.02 : 0))
                .shadow(color: .black.opacity(isDraggingCutter ? 0.18 : 0.0),
                        radius: isDraggingCutter ? 16 : 0,
                        x: 0, y: isDraggingCutter ? 8 : 0)
                .animation(.spring(response: 0.30, dampingFraction: 0.78),
                           value: isDraggingCutter)
                .opacity(phase == .review ? 0 : 1)
                .gesture(cutterGesture(viewSize: size,
                                       innerCenter: innerCenter,
                                       innerW: innerW,
                                       innerH: innerH))
                .zIndex(1)
        }
    }

    private func cutterGesture(viewSize: CGSize,
                               innerCenter: CGPoint,
                               innerW: CGFloat,
                               innerH: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard phase == .live else { return }
                let dist = hypot(value.translation.width, value.translation.height)
                if !isDraggingCutter && dist > dragTapThreshold {
                    isDraggingCutter = true
                    cancelCutterPress()
                }
                if isDraggingCutter {
                    cutterDragDelta = value.translation
                } else {
                    startCutterPress(viewSize: viewSize,
                                     innerCenter: innerCenter,
                                     innerW: innerW,
                                     innerH: innerH)
                }
            }
            .onEnded { value in
                guard phase == .live else { return }
                if isDraggingCutter {
                    cancelCutterPress()
                    cutterOffset = CGSize(
                        width: cutterOffset.width + value.translation.width,
                        height: cutterOffset.height + value.translation.height
                    )
                    cutterDragDelta = .zero
                    isDraggingCutter = false
                } else {
                    cancelCutterPress()
                }
            }
    }

    private func stampView(image: UIImage, width: CGFloat, height: CGFloat) -> some View {
        let shape = PostageStampShape()
        return Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipShape(shape)
            .overlay(shape.stroke(Color.white.opacity(0.65), lineWidth: 0.6))
            .shadow(color: Color.black.opacity(0.22 * Double(liftProgress)),
                    radius: 10 * liftProgress,
                    x: 0,
                    y: 8 * liftProgress)
    }

    // MARK: - Top + bottom chrome

    private var topBar: some View {
        VStack {
            HStack {
                roundIcon("xmark") { dismiss() }
                Spacer()
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    roundIconLabel("photo.on.rectangle")
                }
                .buttonStyle(.plain)
                .disabled(phase == .lifting)
            }
            .padding(.horizontal, 18)
            .padding(.top, 60)
            Spacer()
        }
    }

    private func roundIcon(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            roundIconLabel(systemName)
        }
        .buttonStyle(.plain)
    }

    private func roundIconLabel(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.78))
            .frame(width: 42, height: 42)
            .background(
                ZStack {
                    Circle().fill(Color.white.opacity(0.72))
                    Circle().fill(Color.white.opacity(0.22))
                }
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.75), Color.white.opacity(0.15), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
    }

    private var bottomBar: some View {
        VStack {
            Spacer()
            if phase == .review {
                VStack(spacing: 16) {
                    Button(action: retake) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.65))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    }

                    Button(action: saveStamp) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Save Stamp")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
                                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                        )
                    }
                }
                .padding(.bottom, 44)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    // MARK: - Capture / punch flow

    private func startCamera() {
        // Idempotent. The parent typically pre-warms via the same call when
        // the user taps + Stamp; calling it again here is a no-op aside from
        // re-resolving permission state if the user changed it in Settings.
        camera.requestAuthorizationAndStart()
    }

    private func triggerPunch(viewSize: CGSize,
                              innerCenter: CGPoint,
                              innerW: CGFloat,
                              innerH: CGFloat) {
        let innerRect = CGRect(
            x: innerCenter.x - innerW / 2,
            y: innerCenter.y - innerH / 2,
            width: innerW,
            height: innerH
        )

        withAnimation(.easeIn(duration: 0.10)) { pressAmount = 1.0 }

        // Snapshot the location *now* — by the time the user hits Save they
        // may have walked elsewhere.
        pendingCoordinate = LocationProvider.shared.currentCoordinate()

        Task { @MainActor in
            let cropped: UIImage?
            if let photoLibraryImage {
                cropped = Self.cropAspectFillImage(
                    image: photoLibraryImage,
                    innerWindow: innerRect,
                    viewSize: viewSize
                )
            } else {
                // Capture (or simulator placeholder)
                do {
                    let full = try await camera.capturePhoto()
                    cropped = Self.cropToInnerWindow(
                        image: full,
                        innerWindow: innerRect,
                        previewLayer: camera.previewLayer
                    )
                } catch {
                    cropped = Self.simulatorPlaceholder()
                }
            }

            guard let stamp = cropped else {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.65)) {
                    pressAmount = 0
                }
                errorMessage = "Couldn't capture an image."
                return
            }

            self.stampImage = stamp
            self.phase = .lifting

            withAnimation(.spring(response: 0.30, dampingFraction: 0.65)) {
                self.pressAmount = 0
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.04)) {
                self.liftProgress = 1
            }
            withAnimation(.easeInOut(duration: 0.55).delay(0.10)) {
                self.sceneFade = 1
            }
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                self.phase = .review
                self.reviewTilt = -2.5
            }
        }
    }

    private func startCutterPress(viewSize: CGSize,
                                  innerCenter: CGPoint,
                                  innerW: CGFloat,
                                  innerH: CGFloat) {
        guard cutterPressTask == nil else { return }

        withAnimation(.easeIn(duration: 0.16)) {
            pressAmount = 1.0
        }

        cutterPressTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled,
                  phase == .live,
                  !isDraggingCutter else { return }

            cutterPressTask = nil
            triggerPunch(viewSize: viewSize,
                         innerCenter: innerCenter,
                         innerW: innerW,
                         innerH: innerH)
        }
    }

    private func cancelCutterPress() {
        cutterPressTask?.cancel()
        cutterPressTask = nil
        guard phase == .live else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
            pressAmount = 0
        }
    }

    private func retake() {
        cancelCutterPress()
        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .live
            stampImage = nil
            liftProgress = 0
            sceneFade = 0
            reviewTilt = 0
        }
    }

    private func saveStamp() {
        guard let img = stampImage, let cg = img.cgImage else {
            errorMessage = "No stamp to save."
            return
        }
        let trimmed = stampName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Stamp" : trimmed
        do {
            _ = try MementoStore.save(cgImage: cg,
                                      name: finalName,
                                      in: folder,
                                      latitude: pendingCoordinate?.latitude,
                                      longitude: pendingCoordinate?.longitude,
                                      context: modelContext)
            dismiss()
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    private func loadPhotoLibraryStamp(from item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    await MainActor.run {
                        selectedPhotoItem = nil
                        errorMessage = "Couldn't load that photo."
                    }
                    return
                }

                await MainActor.run {
                    let sourceImage = Self.normalizedImage(image)
                    selectedPhotoItem = nil
                    presentPhotoLibrarySource(sourceImage)
                }
            } catch {
                await MainActor.run {
                    selectedPhotoItem = nil
                    errorMessage = "Couldn't load that photo."
                }
            }
        }
    }

    private func presentPhotoLibrarySource(_ image: UIImage) {
        cancelCutterPress()
        pressAmount = 0
        cutterDragDelta = .zero
        isDraggingCutter = false
        liftProgress = 0
        sceneFade = 0
        reviewTilt = 0
        stampName = ""
        stampImage = nil
        pendingCoordinate = nil
        cutterOffset = .zero
        withAnimation(.easeInOut(duration: 0.22)) {
            photoLibraryImage = image
            phase = .live
        }
    }
}

// MARK: - Postage-stamp clip mask

/// A rectangle with semicircular "perforations" cut out around its perimeter.
struct PostageStampShape: Shape {
    var bite: CGFloat = 5
    var spacing: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var p = Path()

        let countX = max(Int(rect.width / spacing), 1)
        let countY = max(Int(rect.height / spacing), 1)
        let stepX = rect.width / CGFloat(countX)
        let stepY = rect.height / CGFloat(countY)

        p.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top edge: left → right, dipping at each bite
        for i in 0..<countX {
            let cx = rect.minX + (CGFloat(i) + 0.5) * stepX
            p.addLine(to: CGPoint(x: cx - bite, y: rect.minY))
            p.addArc(
                center: CGPoint(x: cx, y: rect.minY),
                radius: bite,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: true
            )
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Right edge: top → bottom
        for j in 0..<countY {
            let cy = rect.minY + (CGFloat(j) + 0.5) * stepY
            p.addLine(to: CGPoint(x: rect.maxX, y: cy - bite))
            p.addArc(
                center: CGPoint(x: rect.maxX, y: cy),
                radius: bite,
                startAngle: .degrees(270),
                endAngle: .degrees(90),
                clockwise: true
            )
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // Bottom edge: right → left
        for i in stride(from: countX - 1, through: 0, by: -1) {
            let cx = rect.minX + (CGFloat(i) + 0.5) * stepX
            p.addLine(to: CGPoint(x: cx + bite, y: rect.maxY))
            p.addArc(
                center: CGPoint(x: cx, y: rect.maxY),
                radius: bite,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: true
            )
        }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

        // Left edge: bottom → top
        for j in stride(from: countY - 1, through: 0, by: -1) {
            let cy = rect.minY + (CGFloat(j) + 0.5) * stepY
            p.addLine(to: CGPoint(x: rect.minX, y: cy + bite))
            p.addArc(
                center: CGPoint(x: rect.minX, y: cy),
                radius: bite,
                startAngle: .degrees(90),
                endAngle: .degrees(270),
                clockwise: true
            )
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Capture + crop helpers

extension StampPunchView {
    /// Returns a bundled image when running in the simulator (or any time the
    /// real camera capture fails) so the punch animation can still be
    /// previewed.
    fileprivate static func simulatorPlaceholder() -> UIImage? {
        for asset in ["cardKassian", "cardLandscape", "cardNoProblem", "it1", "am2"] {
            if let img = UIImage(named: asset) { return img }
        }
        return nil
    }

    fileprivate static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    fileprivate static func cropAspectFillImage(image: UIImage,
                                                innerWindow: CGRect,
                                                viewSize: CGSize) -> UIImage? {
        let normalized = normalizedImage(image)
        guard let cg = normalized.cgImage,
              viewSize.width > 0,
              viewSize.height > 0 else { return normalized }

        let viewRect = CGRect(origin: .zero, size: viewSize)
        let clampedWindow = innerWindow.intersection(viewRect)
        guard !clampedWindow.isNull,
              clampedWindow.width > 0,
              clampedWindow.height > 0 else { return nil }

        let imageW = CGFloat(cg.width)
        let imageH = CGFloat(cg.height)
        let imageAspect = imageW / imageH
        let viewAspect = viewSize.width / viewSize.height
        let visibleImageRect: CGRect

        if imageAspect > viewAspect {
            let visibleW = imageH * viewAspect
            visibleImageRect = CGRect(
                x: (imageW - visibleW) / 2,
                y: 0,
                width: visibleW,
                height: imageH
            )
        } else {
            let visibleH = imageW / viewAspect
            visibleImageRect = CGRect(
                x: 0,
                y: (imageH - visibleH) / 2,
                width: imageW,
                height: visibleH
            )
        }

        let cropRect = CGRect(
            x: visibleImageRect.minX + (clampedWindow.minX / viewSize.width) * visibleImageRect.width,
            y: visibleImageRect.minY + (clampedWindow.minY / viewSize.height) * visibleImageRect.height,
            width: (clampedWindow.width / viewSize.width) * visibleImageRect.width,
            height: (clampedWindow.height / viewSize.height) * visibleImageRect.height
        ).integral

        guard let cropped = cg.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
    }

    /// Crops a full-res capture down to the cutter's inner-window rect by
    /// converting the screen-space rect into a normalized region on the
    /// captured image via the preview layer's coordinate mapping.
    fileprivate static func cropToInnerWindow(image: UIImage,
                                              innerWindow: CGRect,
                                              previewLayer: AVCaptureVideoPreviewLayer?) -> UIImage? {
        let pxSize = CGSize(width: image.size.width * image.scale,
                            height: image.size.height * image.scale)
        guard pxSize.width > 0, pxSize.height > 0 else { return image }

        let normalized: CGRect
        if let layer = previewLayer {
            normalized = layer.metadataOutputRectConverted(fromLayerRect: innerWindow)
        } else {
            // Fall back to an aspect-fill mapping if the layer isn't attached.
            normalized = CGRect(
                x: innerWindow.minX / max(innerWindow.width, 1),
                y: innerWindow.minY / max(innerWindow.height, 1),
                width: 1,
                height: 1
            )
        }
        let clamped = normalized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        let px = CGRect(
            x: clamped.origin.x * pxSize.width,
            y: clamped.origin.y * pxSize.height,
            width: clamped.size.width * pxSize.width,
            height: clamped.size.height * pxSize.height
        ).integral
        guard px.width > 0, px.height > 0, let cg = image.cgImage?.cropping(to: px) else {
            return image
        }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}
