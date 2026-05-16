import SwiftUI
import SwiftData
import AVFoundation
import UIKit

enum SourceTab: String, CaseIterable, Identifiable {
    case house, globe, calendar
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .house:
            return "house"
        case .globe:
            return "map"
        case .calendar:
            return "square.grid.2x2"
        }
    }
}

struct TrayEditor: View {
    enum Mode: String, CaseIterable, Identifiable {
        case boring = "Folder"
        case custom = "Stamps"
        var id: String { rawValue }
    }

    private struct SlotPose {
        let offset: CGSize
        let rotation: Angle
    }

    private struct PaletteDragState {
        let asset: String
        let startLocation: CGPoint
        let startGlobalLocation: CGPoint
        var location: CGPoint
        var globalLocation: CGPoint
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.order) private var folders: [Folder]

    @State private var mode: Mode = .custom

    @State private var activeCardID: UUID?
    @State private var swipeOffset: CGFloat = 0
    @State private var shineCardID: UUID? = nil
    @State private var shineStartDate: Date = .distantPast
    private let shineDuration: TimeInterval = 0.7
    @State private var activeFolderIndex: Int = 1
    @State private var expandedFolderIndex: Int = 1
    @State private var morphProgress: CGFloat = 0

    /// Local visual order of the centered folder's stamps. Tracks Send-to-back /
    /// Bring-to-front actions without mutating the persisted relationship.
    @State private var stampOrder: [UUID] = []
    /// Generation counter that changes when the centered folder swaps, so the
    /// stamp container can apply a single transition rather than animating each
    /// stamp independently.
    @State private var stampSwapToken: UUID = UUID()
    @State private var showStampPunch = false
    /// Shared camera so the AVCaptureSession isn't rebuilt each time the
    /// punch view is presented (saves ~1s of warm-up on second+ presentations).
    @StateObject private var sharedCamera = CameraController()

    private enum NavTab: String, CaseIterable, Identifiable {
        case plus, globe
        var id: String { rawValue }
        var symbol: String { self == .plus ? "plus" : "globe" }
    }
    @State private var navTab: NavTab = .plus
    @State private var navMorphProgress: CGFloat = 0
    @State private var showStampMap: Bool = false
    @State private var showStampCalendar: Bool = false

    @State private var sourceTab: SourceTab = .house
    @State private var sourceMorphProgress: CGFloat = 0

    // MARK: - Folder decoration state

    private static let stickerPaletteAssets: [String] = [
        "FlagSticker", "ToriiSticker", "JapanDecor",
        "Lemon", "Tulip", "DutchFlag", "ItalyFlag"
    ]

    /// Immediate UI cache for folder decorations. SwiftData persists the same
    /// array, but this keeps drag/drop feedback independent of model refreshes.
    @State private var decorationCache: [UUID: [PlacedSticker]] = [:]
    /// Asset + finger location while dragging a sticker out of the palette.
    @State private var paletteDrag: PaletteDragState? = nil
    /// Currently-dragged placed sticker id and its starting normalized position.
    @State private var placedDrag: (id: UUID, startX: CGFloat, startY: CGFloat)? = nil
    /// Frames captured via PreferenceKey in the editor coordinate space.
    @State private var canvasRect: CGRect = .zero
    @State private var canvasGlobalRect: CGRect = .zero
    @State private var folderCardRect: CGRect = .zero
    @State private var folderCardGlobalRect: CGRect = .zero
    @State private var paletteItemRects: [String: CGRect] = [:]
    @State private var paletteItemGlobalRects: [String: CGRect] = [:]
    @State private var trashRect: CGRect = .zero
    @State private var trashGlobalRect: CGRect = .zero
    @State private var trashHot: Bool = false

    private static let editorCoordSpace = "trayEditorSpace"

    private let trayCorner: CGFloat = 36
    private let canvasHeight: CGFloat = 240
    private static let sourceAccentColor = Color(red: 0.31, green: 0.48, blue: 0.96)
    private static let glassButtonFill = Color.white.opacity(0.72)
    private static let floatingPillFill = Color(red: 0.965, green: 0.965, blue: 0.970)

    // MARK: - Derived folder/stamp state

    private var centeredFolder: Folder? {
        folders.indices.contains(activeFolderIndex) ? folders[activeFolderIndex] : nil
    }

    @ViewBuilder
    private func folderCardView(idx: Int, folder: Folder) -> some View {
        let peeks: [String]? = folder.peekPhotoAssets.isEmpty ? nil : folder.peekPhotoAssets
        FolderCard(
            title: folder.name,
            photoCount: folder.stamps.count,
            leftSticker: folder.leftStickerAsset,
            rightSticker: folder.rightStickerAsset,
            isExpanded: idx == expandedFolderIndex,
            photoAssets: peeks,
            decorations: decorations(for: folder)
        )
        .frame(width: 160)
    }

    private func decorations(for folder: Folder) -> [PlacedSticker] {
        decorationCache[folder.id] ?? folder.placedStickers
    }

    private var currentDecorations: [PlacedSticker] {
        guard let folder = centeredFolder else { return [] }
        return decorations(for: folder)
    }

    private func updateCurrentDecorations(save: Bool = true,
                                          _ transform: (inout [PlacedSticker]) -> Void) {
        guard let folder = centeredFolder else { return }
        var arr = decorations(for: folder)
        transform(&arr)
        decorationCache[folder.id] = arr
        folder.placedStickers = arr
        if save {
            try? modelContext.save()
        }
    }

    private func saveDecorationChanges() {
        try? modelContext.save()
    }

    private func syncDecorationCache(for folder: Folder) {
        if decorationCache[folder.id] == nil {
            decorationCache[folder.id] = folder.placedStickers
        }
    }

    private var currentStamps: [Memento] {
        guard let folder = centeredFolder else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: folder.stamps.map { ($0.id, $0) })
        let ordered = stampOrder.compactMap { byID[$0] }
        let known = Set(stampOrder)
        let extras = folder.stamps.filter { !known.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        return ordered + extras
    }

    private var activeStamp: Memento? {
        guard let activeCardID else { return currentStamps.first }
        return currentStamps.first { $0.id == activeCardID } ?? currentStamps.first
    }

    var body: some View {
        ZStack {
            Color(red: 0.93, green: 0.93, blue: 0.94)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topLibraryArea
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            trayContent
                .padding(.horizontal, 10)
                .padding(.bottom, 0)
                .ignoresSafeArea(.container, edges: .bottom)
                .offset(y: 16)
        }
        .onAppear { syncCenteredFolder() }
        .onChange(of: centeredFolder?.id) { _, _ in
            syncCenteredFolder()
        }
        .onChange(of: folders.count) { _, _ in
            syncCenteredFolder()
        }
        .onChange(of: centeredFolder?.stamps.map(\.id) ?? []) { _, _ in
            syncCenteredFolder()
        }
        .fullScreenCover(isPresented: $showStampPunch) {
            if let folder = centeredFolder {
                StampPunchView(folder: folder, camera: sharedCamera)
            }
        }
        .fullScreenCover(isPresented: $showStampMap) {
            StampMapView()
        }
        .fullScreenCover(isPresented: $showStampCalendar) {
            StampCalendarView()
        }
        .onChange(of: showStampMap) { _, isShown in
            if !isShown && navTab == .globe {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                    navTab = .plus
                }
            }
            if !isShown && sourceTab == .globe {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.62)) {
                    sourceTab = .house
                }
            }
        }
        .onChange(of: showStampCalendar) { _, isShown in
            if !isShown && sourceTab == .calendar {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.62)) {
                    sourceTab = .house
                }
            }
        }
    }

    private var topLibraryArea: some View {
        VStack(spacing: 16) {
            libraryHeader
                .padding(.horizontal, 18)
                .frame(height: 42)
                .padding(.top, 4)
                .offset(y: -4)

            folderCarousel
        }
        .padding(.bottom, 10)
    }

    private var folderCarousel: some View {
        HStack(alignment: .top, spacing: 18) {
            ForEach(Array(folders.enumerated()), id: \.element.id) { idx, folder in
                folderCardView(idx: idx, folder: folder)
            }
        }
        .offset(x: CGFloat(1 - activeFolderIndex) * 178)
        .animation(.spring(response: 0.26, dampingFraction: 0.86), value: activeFolderIndex)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    let threshold: CGFloat = 40
                    let previous = activeFolderIndex
                    let maxIndex = max(folders.count - 1, 0)
                    var next = previous
                    if value.translation.width < -threshold {
                        next = min(previous + 1, maxIndex)
                    } else if value.translation.width > threshold {
                        next = max(previous - 1, 0)
                    }
                    guard next != previous else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    // Collapse the old folder immediately so the new
                    // expansion reads cleanly after the slide.
                    withAnimation(.easeOut(duration: 0.12)) {
                        expandedFolderIndex = -1
                    }
                    activeFolderIndex = next
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                            expandedFolderIndex = next
                        }
                    }
                }
        )
    }

    private func syncCenteredFolder() {
        guard let folder = centeredFolder else {
            stampOrder = []
            activeCardID = nil
            return
        }
        syncDecorationCache(for: folder)
        let newOrder = folder.stamps
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.id)
        withAnimation(.easeInOut(duration: 0.30)) {
            stampOrder = newOrder
            stampSwapToken = UUID()
        }
        let defaultIdx = newOrder.count >= 3 ? 1 : 0
        if let active = activeCardID, newOrder.contains(active) {
            // keep existing selection
        } else {
            activeCardID = newOrder.indices.contains(defaultIdx)
                ? newOrder[defaultIdx]
                : newOrder.first
        }
    }

    private var libraryHeader: some View {
        ZStack {
            Text("Library")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black)
            HStack {
                headerCircleButton(systemName: "plus") { }
                Spacer()
                headerCircleButton(systemName: "ellipsis") { }
            }
        }
    }

    private var navPillBar: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height
            let inset: CGFloat = 3
            let segW = (totalW - inset * 2) / CGFloat(NavTab.allCases.count)
            let segH = totalH - inset * 2
            let bubbleX = inset + (navTab == .plus ? 0 : segW)

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))

                navMovingBubble(width: segW, height: segH)
                    .offset(x: bubbleX, y: inset)
                    .animation(.spring(response: 0.46, dampingFraction: 0.62), value: navTab)

                HStack(spacing: 0) {
                    ForEach(NavTab.allCases) { tab in
                        let selected = (navTab == tab)
                        Image(systemName: tab.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selected ? Color.black.opacity(0.85) : Color.black.opacity(0.40))
                            .animation(.easeInOut(duration: 0.22), value: navTab)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { selectNavTab(tab) }
                    }
                }
                .padding(inset)
            }
        }
        .frame(width: 78, height: 34)
    }

    private func selectNavTab(_ tab: NavTab) {
        if navTab != tab {
            navTab = tab
            withAnimation(.easeOut(duration: 0.22)) {
                navMorphProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                    navMorphProgress = 0
                }
            }
        }
        if tab == .globe { showStampMap = true }
    }

    private func navMovingBubble(width: CGFloat, height: CGFloat) -> some View {
        let m = Double(navMorphProgress)
        return Capsule()
            .fill(Color.black.opacity(0.06))
            .frame(width: width, height: height)
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.75),
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.6
                    )
            )
            .overlay(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(width: width, height: height)
                    .opacity(0.55 * m)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.10 + 0.08 * m),
                    radius: 4 + 4 * navMorphProgress,
                    x: 0,
                    y: 2 + 1 * navMorphProgress)
            .scaleEffect(x: 1.0 + 0.08 * navMorphProgress,
                         y: 1.0 - 0.06 * navMorphProgress)
            .blur(radius: 0.5 * navMorphProgress)
            .opacity(1.0 - 0.10 * m)
    }

    private func headerCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.78))
                .frame(width: 42, height: 42)
                .background(
                    ZStack {
                        Circle().fill(Self.glassButtonFill)
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
                .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tray

    private var trayContent: some View {
        VStack(spacing: 0) {
            dragHandle
                .padding(.top, 10)
                .padding(.bottom, 14)

            segmentedControl
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            canvasArea
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            middleControlsSection

            bottomBar
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
        }
        .coordinateSpace(name: Self.editorCoordSpace)
        .clipShape(RoundedRectangle(cornerRadius: trayCorner, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: trayCorner, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 6)
        )
        .overlay(alignment: .topLeading) { dragGhostOverlay }
    }

    @ViewBuilder
    private var canvasArea: some View {
        if mode == .boring {
            folderDecoratingCanvas
        } else {
            canvas
        }
    }

    private var folderDecoratingCanvas: some View {
        ZStack {
            dottedBackground
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let folder = centeredFolder {
                FolderCard(
                    title: folder.name,
                    photoCount: folder.stamps.count,
                    leftSticker: folder.leftStickerAsset,
                    rightSticker: folder.rightStickerAsset,
                    isExpanded: false,
                    photoAssets: folder.peekPhotoAssets.isEmpty ? nil : folder.peekPhotoAssets,
                    decorations: currentDecorations,
                    showTitle: false
                )
                .frame(width: 280, height: 224)
                .background(
                    GeometryReader { geo in
                        let named = geo.frame(in: .named(Self.editorCoordSpace))
                        let global = geo.frame(in: .global)
                        Color.clear
                            .onChange(of: named, initial: true) { _, new in
                                folderCardRect = new
                            }
                            .onChange(of: global, initial: true) { _, new in
                                folderCardGlobalRect = new
                            }
                    }
                )
                .overlay(placedStickerInteractionLayer)
            }
        }
        .frame(height: canvasHeight)
        .background(
            GeometryReader { geo in
                let named = geo.frame(in: .named(Self.editorCoordSpace))
                let global = geo.frame(in: .global)
                Color.clear
                    .onChange(of: named, initial: true) { _, new in
                        canvasRect = new
                    }
                    .onChange(of: global, initial: true) { _, new in
                        canvasGlobalRect = new
                    }
            }
        )
    }

    /// Hit-targets for already-placed stickers, sized to match the FolderCard
    /// decoration overlay so dragging picks the right sticker.
    private var placedStickerInteractionLayer: some View {
        GeometryReader { geo in
            // FolderCard inner card width = geo.width; glassW per FolderCard's
            // own math = w * 0.648 * 1.24.
            let glassW = geo.size.width * 0.648 * 1.24
            let folderYNudge = geo.size.width * 0.648 * 0.06
            ZStack {
                ForEach(currentDecorations) { sticker in
                    Color.clear
                        .frame(width: glassW * 0.20 * sticker.scale,
                               height: glassW * 0.20 * sticker.scale)
                        .contentShape(Rectangle())
                        .offset(x: sticker.normX * glassW,
                                y: sticker.normY * glassW + folderYNudge)
                        .gesture(placedStickerDragGesture(for: sticker, glassW: glassW))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func placedStickerDragGesture(for sticker: PlacedSticker,
                                          glassW: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.editorCoordSpace))
            .onChanged { value in
                if placedDrag?.id != sticker.id {
                    placedDrag = (sticker.id, sticker.normX, sticker.normY)
                }
                trashHot = trashRect.contains(value.location)
                let startX = placedDrag?.startX ?? sticker.normX
                let startY = placedDrag?.startY ?? sticker.normY
                let nx = startX + value.translation.width / max(glassW, 1)
                let ny = startY + value.translation.height / max(glassW, 1)
                updateCurrentDecorations(save: false) { arr in
                    if let i = arr.firstIndex(where: { $0.id == sticker.id }) {
                        arr[i].normX = clampedStickerNorm(nx)
                        arr[i].normY = clampedStickerNorm(ny)
                    }
                }
            }
            .onEnded { value in
                let inTrash = trashRect.contains(value.location)
                if inTrash {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    updateCurrentDecorations { arr in
                        arr.removeAll { $0.id == sticker.id }
                    }
                } else {
                    saveDecorationChanges()
                }
                placedDrag = nil
                trashHot = false
            }
    }

    // MARK: - Middle controls section (constant height to keep tray stable)

    /// Matches the stamps-mode pill + title block + their bottom paddings,
    /// so the tray's overall height is identical across modes and the rounded
    /// top corners stay in the same place when the user toggles Folder/Stamps.
    private static let middleSectionHeight: CGFloat = 138

    @ViewBuilder
    private var middleControlsSection: some View {
        if mode == .boring {
            decoratingControls
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(height: Self.middleSectionHeight)
        } else {
            VStack(spacing: 0) {
                floatingControlPill
                    .padding(.bottom, 18)
                titleBlock
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.middleSectionHeight)
        }
    }

    // MARK: - Decorating controls (palette + trash)

    private var decoratingControls: some View {
        HStack(spacing: 12) {
            stickerPalette
            trashZone
        }
    }

    private var stickerPalette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.stickerPaletteAssets, id: \.self) { asset in
                    paletteStickerButton(asset: asset)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .scrollDisabled(paletteDrag != nil)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Self.floatingPillFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }

    private func paletteStickerButton(asset: String) -> some View {
        Image(asset)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 44, height: 44)
            .opacity(paletteDrag?.asset == asset ? 0.35 : 1.0)
            .contentShape(Rectangle())
            .background(
                GeometryReader { geo in
                    let named = geo.frame(in: .named(Self.editorCoordSpace))
                    let global = geo.frame(in: .global)
                    Color.clear
                        .onChange(of: named, initial: true) { _, new in
                            paletteItemRects[asset] = new
                        }
                        .onChange(of: global, initial: true) { _, new in
                            paletteItemGlobalRects[asset] = new
                        }
                }
            )
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        if paletteDrag == nil {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        var drag = paletteDrag ?? PaletteDragState(
                            asset: asset,
                            startLocation: paletteDragStartLocation(for: asset, value: value),
                            startGlobalLocation: paletteDragStartGlobalLocation(for: asset, value: value),
                            location: .zero,
                            globalLocation: value.location
                        )
                        drag.location = paletteDragLocation(for: drag, value: value)
                        drag.globalLocation = paletteDragGlobalLocation(for: drag, value: value)
                        trashHot = trashGlobalRect.contains(drag.globalLocation)
                        paletteDrag = drag
                    }
                    .onEnded { value in
                        var drag = paletteDrag ?? PaletteDragState(
                            asset: asset,
                            startLocation: paletteDragStartLocation(for: asset, value: value),
                            startGlobalLocation: paletteDragStartGlobalLocation(for: asset, value: value),
                            location: .zero,
                            globalLocation: value.location
                        )
                        drag.location = paletteDragLocation(for: drag, value: value)
                        drag.globalLocation = paletteDragGlobalLocation(for: drag, value: value)
                        defer {
                            paletteDrag = nil
                            trashHot = false
                        }
                        let dropLocation = drag.globalLocation
                        print("[PALETTE .onEnded] asset=\(asset) dropLocation=\(dropLocation) trashGlobalRect=\(trashGlobalRect) folderCardGlobalRect=\(folderCardGlobalRect) canvasGlobalRect=\(canvasGlobalRect) frontCoverDropGlobalRect=\(frontCoverDropGlobalRect)")
                        // If the user releases on top of the trash zone, do
                        // not place anything (treat as cancel).
                        if trashGlobalRect.contains(dropLocation) {
                            print("[PALETTE .onEnded] cancelled — drop on trash")
                            return
                        }

                        guard shouldCommitPaletteDrop(at: dropLocation) else {
                            print("[PALETTE .onEnded] cancelled — shouldCommitPaletteDrop=false")
                            return
                        }

                        let normalized = normalizedStickerPosition(for: dropLocation)
                        let placed = PlacedSticker(
                            asset: asset,
                            normX: normalized.x,
                            normY: normalized.y,
                            rotation: Double.random(in: -10...10)
                        )
                        updateCurrentDecorations { $0.append(placed) }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
            )
    }

    private func paletteDragStartLocation(for asset: String,
                                          value: DragGesture.Value) -> CGPoint {
        guard let rect = paletteItemRects[asset], rect != .zero else {
            return localPoint(fromGlobal: value.startLocation)
        }
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private func paletteDragStartGlobalLocation(for asset: String,
                                                value: DragGesture.Value) -> CGPoint {
        guard let rect = paletteItemGlobalRects[asset], rect != .zero else {
            return value.startLocation
        }
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private func paletteDragLocation(for drag: PaletteDragState,
                                     value: DragGesture.Value) -> CGPoint {
        CGPoint(
            x: drag.startLocation.x + value.translation.width,
            y: drag.startLocation.y + value.translation.height
        )
    }

    private func paletteDragGlobalLocation(for drag: PaletteDragState,
                                           value: DragGesture.Value) -> CGPoint {
        CGPoint(
            x: drag.startGlobalLocation.x + value.translation.width,
            y: drag.startGlobalLocation.y + value.translation.height
        )
    }

    private func localPoint(fromGlobal point: CGPoint) -> CGPoint {
        guard folderCardGlobalRect != .zero,
              folderCardRect != .zero else {
            return point
        }
        let trayOrigin = CGPoint(
            x: folderCardGlobalRect.minX - folderCardRect.minX,
            y: folderCardGlobalRect.minY - folderCardRect.minY
        )
        return CGPoint(x: point.x - trayOrigin.x,
                       y: point.y - trayOrigin.y)
    }

    private var measuredFolderDropGlobalRect: CGRect {
        folderCardGlobalRect == .zero ? canvasGlobalRect : folderCardGlobalRect
    }

    private var frontCoverDropGlobalRect: CGRect {
        let cardRect = measuredFolderDropGlobalRect
        guard cardRect != .zero else { return .zero }

        let cardW = cardRect.width > 0 ? cardRect.width : 280
        let glassW = cardW * 0.648 * 1.24
        let folderYNudge = cardW * 0.648 * 0.06
        let layerHeight = glassW * 0.92
        let frontHeight = glassW * (104.0 / 184.0)
        let frontYOffset = glassW * 0.13
        let frontCenter = CGPoint(
            x: cardRect.midX,
            y: cardRect.midY + folderYNudge + frontYOffset
        )

        return CGRect(
            x: frontCenter.x - glassW / 2,
            y: frontCenter.y - frontHeight / 2,
            width: glassW,
            height: min(frontHeight, layerHeight)
        )
    }

    private func shouldCommitPaletteDrop(at location: CGPoint) -> Bool {
        let rect = frontCoverDropGlobalRect
        guard rect != .zero else { return false }
        return rect.insetBy(dx: -14, dy: -14).contains(location)
    }

    private func normalizedStickerPosition(for location: CGPoint) -> CGPoint {
        let measuredCardRect = measuredFolderDropGlobalRect
        let cardW = measuredCardRect.width > 0 ? measuredCardRect.width : 280
        let glassW = cardW * 0.648 * 1.24
        let folderYNudge = cardW * 0.648 * 0.06

        guard measuredCardRect != .zero else {
            return .zero
        }

        let cardCenter = CGPoint(x: measuredCardRect.midX, y: measuredCardRect.midY)
        let nx = (location.x - cardCenter.x) / max(glassW, 1)
        let ny = (location.y - cardCenter.y - folderYNudge) / max(glassW, 1)
        return CGPoint(x: clampedStickerNorm(nx), y: clampedStickerNorm(ny))
    }

    private func clampedStickerNorm(_ value: CGFloat) -> CGFloat {
        max(min(value, 0.55), -0.55)
    }

    private var trashZone: some View {
        ZStack {
            Circle()
                .fill(trashHot ? Color.red.opacity(0.18) : Color.white)
                .overlay(
                    Circle().stroke(trashHot ? Color.red.opacity(0.7) : Color.black.opacity(0.08),
                                    lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

            Image(systemName: "trash")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(trashHot ? Color.red : Color.black.opacity(0.55))
                .scaleEffect(trashHot ? 1.15 : 1.0)
        }
        .frame(width: 56, height: 56)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: trashHot)
        .background(
            GeometryReader { geo in
                let named = geo.frame(in: .named(Self.editorCoordSpace))
                let global = geo.frame(in: .global)
                Color.clear
                    .onChange(of: named, initial: true) { _, new in
                        trashRect = new
                    }
                    .onChange(of: global, initial: true) { _, new in
                        trashGlobalRect = new
                    }
            }
        )
    }

    @ViewBuilder
    private var dragGhostOverlay: some View {
        if let drag = paletteDrag {
            Image(drag.asset)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                .position(drag.location)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Drag handle

    private var dragHandle: some View {
        Capsule()
            .fill(Color.black.opacity(0.18))
            .frame(width: 38, height: 5)
    }

    // MARK: - Segmented control

    private static let pillBaseColor    = Color(red: 0.965, green: 0.965, blue: 0.970)
    private static let pillInactiveText = Color(red: 110/255.0, green: 110/255.0, blue: 115/255.0)
    private static let pillActiveBubble = Color(red:   5/255.0, green:   5/255.0, blue:   5/255.0)

    private var segmentedControl: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height
            let inset: CGFloat = 4
            let segW = (totalW - inset * 2) / CGFloat(Mode.allCases.count)
            let segH = totalH - inset * 2
            let isFolder = (mode == .boring)
            let bubbleX = inset + (isFolder ? 0 : segW)

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Self.pillBaseColor)
                    .overlay(
                        Capsule().stroke(Color.black.opacity(0.035), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

                movingBubble(width: segW, height: segH)
                    .offset(x: bubbleX, y: inset)
                    .animation(.spring(response: 0.46, dampingFraction: 0.62), value: mode)

                HStack(spacing: 0) {
                    ForEach(Mode.allCases) { option in
                        let selected = (mode == option)
                        Text(option.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selected ? Self.sourceAccentColor : Self.pillInactiveText)
                            .animation(.easeInOut(duration: 0.22), value: mode)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { selectMode(option) }
                    }
                }
                .padding(inset)
            }
        }
        .frame(height: 40)
        .frame(maxWidth: 200)
    }

    private func selectMode(_ option: Mode) {
        guard mode != option else { return }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        mode = option
        withAnimation(.easeOut(duration: 0.22)) {
            morphProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                morphProgress = 0
            }
        }
    }

    private func movingBubble(width: CGFloat, height: CGFloat) -> some View {
        SourceMovingBubble(
            width: width,
            height: height,
            progress: morphProgress,
            accentColor: Self.sourceAccentColor
        )
    }

    // MARK: - Canvas

    private var canvas: some View {
        canvasView(stamps: currentStamps)
    }

    private func canvasView(stamps: [Memento]) -> some View {
        ZStack {
            dottedBackground
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            ZStack {
                ForEach(visibleCanvasStamps(in: stamps), id: \.id) { stamp in
                    cardView(for: stamp, in: stamps)
                }
            }
            .id(stampSwapToken)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: 30, y: 0)),
                removal: .opacity.combined(with: .offset(x: -30, y: 0))
            ))
        }
        .frame(height: canvasHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    swipeOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 40
                    let previousID = activeCardID
                    withAnimation(.snappy(duration: 0.28)) {
                        if value.translation.width < -threshold {
                            cycleActive(forward: true)
                        } else if value.translation.width > threshold {
                            cycleActive(forward: false)
                        }
                        swipeOffset = 0
                    }
                    if let newID = activeCardID, newID != previousID {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        triggerShine(for: newID)
                    }
                }
        )
    }

    private func visibleCanvasStamps(in stamps: [Memento]) -> [Memento] {
        guard !stamps.isEmpty else { return [] }
        guard let activeID = activeCardID,
              let activeIdx = stamps.firstIndex(where: { $0.id == activeID }) else {
            return Array(stamps.prefix(5))
        }

        let lower = max(activeIdx - 2, 0)
        let upper = min(activeIdx + 2, stamps.count - 1)
        return Array(stamps[lower...upper])
    }

    private func slotPose(for cardID: UUID, in stamps: [Memento]) -> SlotPose {
        guard let activeID = activeCardID,
              let activeIdx = stamps.firstIndex(where: { $0.id == activeID }),
              let cardIdx = stamps.firstIndex(where: { $0.id == cardID }) else {
            return SlotPose(offset: .zero, rotation: .degrees(0))
        }
        let slotSpacing: CGFloat = 95
        let diff = cardIdx - activeIdx
        switch diff {
        case 0:
            return SlotPose(offset: CGSize(width: 0, height: -4), rotation: .degrees(-8))
        case 1:
            return SlotPose(offset: CGSize(width: slotSpacing, height: 14), rotation: .degrees(2))
        case 2:
            return SlotPose(offset: CGSize(width: slotSpacing * 2, height: 6), rotation: .degrees(5))
        case -1:
            return SlotPose(offset: CGSize(width: -slotSpacing, height: 10), rotation: .degrees(-4))
        case -2:
            return SlotPose(offset: CGSize(width: -slotSpacing * 2, height: 18), rotation: .degrees(-2))
        default:
            // Beyond visible slots: extrapolate so off-stack cards stay off-screen
            // instead of collapsing to center and showing behind the active card.
            let x = CGFloat(diff) * slotSpacing
            return SlotPose(offset: CGSize(width: x, height: diff > 0 ? 6 : 18),
                            rotation: .degrees(diff > 0 ? 5 : -2))
        }
    }

    private func cycleActive(forward: Bool) {
        let stamps = currentStamps
        guard let activeID = activeCardID,
              let idx = stamps.firstIndex(where: { $0.id == activeID }) else { return }
        let nextIdx = forward ? min(idx + 1, stamps.count - 1)
                              : max(idx - 1, 0)
        let newID = stamps[nextIdx].id
        guard newID != activeID else { return }
        activeCardID = newID
    }

    private func triggerShine(for cardID: UUID) {
        shineCardID = cardID
        shineStartDate = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + shineDuration + 0.05) {
            if shineCardID == cardID {
                shineCardID = nil
            }
        }
    }

    private func shineOverlay(progress: CGFloat) -> some View {
        // Card size 116×168. Band is wide (full width + overhang) and tall
        // enough to read as a soft swipe of light, with a slight upward tilt
        // matching the reference screenshots. Sweeps from below the card to
        // above it as progress goes 0→1.
        let cardHeight: CGFloat = StampVisualMetrics.trayHeight
        let bandHeight: CGFloat = 68
        let bandWidth: CGFloat = 180
        let tilt: Angle = .degrees(-12)
        // Travel must move the band fully past both ends of the card.
        let travel = cardHeight + bandHeight
        let y = (travel / 2) - progress * travel
        // Fade in/out at the endpoints so it doesn't pop.
        let fade: CGFloat = {
            if progress < 0.10 { return max(0, progress / 0.10) }
            if progress > 0.90 { return max(0, (1.0 - progress) / 0.10) }
            return 1.0
        }()
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0),
                        .white.opacity(0.55),
                        .white.opacity(0.95),
                        .white.opacity(0.55),
                        .white.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: bandWidth, height: bandHeight)
            .rotationEffect(tilt)
            .offset(y: y)
            .opacity(Double(max(0, min(1, fade))))
            .blur(radius: 3)
    }

    @ViewBuilder
    private func cardView(for stamp: Memento, in stamps: [Memento]) -> some View {
        let isActive = stamp.id == activeCardID
        let pose = slotPose(for: stamp.id, in: stamps)
        let liveX = pose.offset.width + swipeOffset
        let diff: Int = {
            guard let activeID = activeCardID,
                  let activeIdx = stamps.firstIndex(where: { $0.id == activeID }),
                  let cardIdx = stamps.firstIndex(where: { $0.id == stamp.id }) else {
                return 0
            }
            return cardIdx - activeIdx
        }()
        let baseOpacity: Double = abs(diff) > 2 ? 0 : (isActive ? 1.0 : 0.42)
        let cardSize = StampVisualMetrics.traySize
        let stampShape = PostageStampShape(bite: 6.2, spacing: 15.0)

        ZStack {
            cardImage(for: stamp)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardSize.width, height: cardSize.height)
                .overlay {
                    if shineCardID == stamp.id {
                        TimelineView(.animation(minimumInterval: 1.0/60.0)) { ctx in
                            let elapsed = ctx.date.timeIntervalSince(shineStartDate)
                            let raw = min(max(elapsed / shineDuration, 0), 1)
                            // easeInOut over the progress axis
                            let eased: Double = raw < 0.5
                                ? 2 * raw * raw
                                : 1 - pow(-2 * raw + 2, 2) / 2
                            shineOverlay(progress: CGFloat(eased))
                        }
                        .allowsHitTesting(false)
                    }
                }
                .clipShape(stampShape)
                .background {
                    stampShape
                        .fill(Color.black.opacity(isActive ? 0.08 : 0.035))
                        .frame(width: cardSize.width, height: cardSize.height)
                        .scaleEffect(1.015)
                        .blur(radius: isActive ? 1.1 : 0.7)
                        .offset(y: isActive ? 1.5 : 0.8)
                }
                .overlay {
                    stampShape
                        .stroke(Color.black.opacity(isActive ? 0.055 : 0.025), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(isActive ? 0.16 : 0.05),
                        radius: isActive ? 10 : 4,
                        x: 0, y: isActive ? 6 : 2)
                .opacity(baseOpacity)
        }
        .scaleEffect(isActive ? 1.12 : 1.0)
        .rotationEffect(pose.rotation)
        .offset(x: liveX, y: pose.offset.height)
        .zIndex(isActive ? 100 : 0)
    }

    private func cardImage(for stamp: Memento) -> Image {
        if let ui = MementoStore.image(for: stamp) {
            return Image(uiImage: ui)
        }
        return Image(systemName: "photo")
    }

    private var dottedBackground: some View {
        Canvas { context, size in
            let spacing: CGFloat = 10
            let dotRadius: CGFloat = 0.9
            let dotColor = Color.black.opacity(0.10)
            var y: CGFloat = spacing
            while y < size.height {
                var x: CGFloat = spacing
                while x < size.width {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius,
                                      width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    x += spacing
                }
                y += spacing
            }
        }
        .background(Color(red: 0.985, green: 0.985, blue: 0.99))
    }

    // MARK: - Floating control pill (Crop / Back / Front)

    private var floatingControlPill: some View {
        HStack(spacing: 22) {
            Button(action: { /* keeps selection */ }) {
                HStack(spacing: 6) {
                    Image(systemName: "crop")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Edit")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.black)
            }

            Button(action: sendActiveCardToBack) {
                Text("Share")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
            }

            Button(action: bringActiveCardToFront) {
                Text("Story")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(Self.floatingPillFill)
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.62),
                                    Color.white.opacity(0.18)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Capsule().stroke(Color.black.opacity(0.035), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    private func sendActiveCardToBack() {
        guard let activeID = activeCardID,
              let idx = stampOrder.firstIndex(of: activeID) else { return }
        let item = stampOrder.remove(at: idx)
        stampOrder.insert(item, at: 0)
    }

    private func bringActiveCardToFront() {
        guard let activeID = activeCardID,
              let idx = stampOrder.firstIndex(of: activeID) else { return }
        let item = stampOrder.remove(at: idx)
        stampOrder.append(item)
    }

    // MARK: - Title block

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(activeStamp?.name ?? "Stamp")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(activeStampDateText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.black.opacity(0.35))
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
    }

    private var activeStampDateText: String {
        guard let stamp = activeStamp else { return "" }
        return stamp.createdAt.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .year()
        )
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            sourcePill
                .frame(maxWidth: .infinity)
            saveButton
        }
    }

    private var sourcePill: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height
            let inset: CGFloat = 4
            let segCount = CGFloat(SourceTab.allCases.count)
            let segW = (totalW - inset * 2) / segCount
            let segH = totalH - inset * 2
            let activeIdx = SourceTab.allCases.firstIndex(of: sourceTab) ?? 0
            let bubbleX = inset + CGFloat(activeIdx) * segW

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 7, x: 0, y: 2)

                sourceMovingBubble(width: segW, height: segH)
                    .offset(x: bubbleX, y: inset)
                    .animation(.spring(response: 0.46, dampingFraction: 0.62), value: sourceTab)

                HStack(spacing: 0) {
                    ForEach(SourceTab.allCases) { tab in
                        let selected = (sourceTab == tab)
                        Image(systemName: tab.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selected ? Self.sourceAccentColor : Color.black.opacity(0.42))
                            .animation(.easeInOut(duration: 0.22), value: sourceTab)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { selectSourceTab(tab) }
                    }
                }
                .padding(inset)
            }
        }
        .frame(height: 44)
    }

    private func selectSourceTab(_ tab: SourceTab) {
        if sourceTab != tab {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            sourceTab = tab
            withAnimation(.easeOut(duration: 0.22)) {
                sourceMorphProgress = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                    sourceMorphProgress = 0
                }
            }
        }

        if tab == .globe {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                guard sourceTab == .globe else { return }
                showStampMap = true
            }
        }

        if tab == .calendar {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                guard sourceTab == .calendar else { return }
                showStampCalendar = true
            }
        }
    }

    private func sourceMovingBubble(width: CGFloat, height: CGFloat) -> some View {
        SourceMovingBubble(
            width: width,
            height: height,
            progress: sourceMorphProgress,
            accentColor: Self.sourceAccentColor
        )
    }

    private var saveButton: some View {
        Button(action: handleSave) {
            HStack(spacing: 7) {
                NewStampIcon()
                    .frame(width: 22, height: 22)
                Text("new")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.black.opacity(0.42))
            .padding(.horizontal, 24)
            .frame(height: 44)
            .background(
                Capsule()
                    .fill(Color.white)
                    .overlay(
                        Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 7, x: 0, y: 2)
            )
            .opacity(showStampPunch ? 0.55 : 1.0)
        }
        .disabled(showStampPunch)
    }

    private func handleSave() {
        guard centeredFolder != nil else { return }
        guard !showStampPunch else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Present immediately. The camera handles permission + simulator
        // internally so the cover never blocks waiting for hardware.
        sharedCamera.requestAuthorizationAndStart()
        showStampPunch = true
    }
}

private struct NewStampIcon: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let stampSide = size * 0.82
            let badgeSize = size * 0.52
            let stampShape = PostageStampShape(bite: stampSide * 0.075,
                                               spacing: stampSide * 0.18)

            ZStack {
                stampShape
                    .fill(Color.white)
                    .overlay(stampShape.stroke(Color.black.opacity(0.42), lineWidth: 1.0))
                    .frame(width: stampSide, height: stampSide)
                    .shadow(color: .black.opacity(0.10), radius: 1.2, x: 0, y: 0.5)
                    .offset(x: -size * 0.08, y: size * 0.08)

                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.42))
                    Image(systemName: "plus")
                        .font(.system(size: badgeSize * 0.55, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: badgeSize, height: badgeSize)
                .offset(x: size * 0.22, y: -size * 0.22)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

private struct SourceMovingBubble: View {
    let width: CGFloat
    let height: CGFloat
    let progress: CGFloat
    let accentColor: Color

    private var progressDouble: Double {
        Double(progress)
    }

    var body: some View {
        Capsule()
            .fill(accentColor.opacity(0.12))
            .frame(width: width, height: height)
            .overlay(border)
            .overlay(sheen)
            .shadow(
                color: Color.black.opacity(0.08 + 0.06 * progressDouble),
                radius: 4 + 4 * progress,
                x: 0,
                y: 2 + progress
            )
            .scaleEffect(x: 1.0 + 0.08 * progress, y: 1.0 - 0.06 * progress)
            .blur(radius: 0.5 * progress)
            .opacity(1.0 - 0.10 * progressDouble)
    }

    private var border: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.80),
                        accentColor.opacity(0.12),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.6
            )
    }

    private var sheen: some View {
        Capsule()
            .fill(Color.white.opacity(0.28))
            .frame(width: width, height: height)
            .opacity(0.55 * progressDouble)
            .allowsHitTesting(false)
    }
}

private struct CanvasRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct CanvasGlobalRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct FolderCardRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct FolderCardGlobalRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct PaletteItemRectKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct PaletteItemGlobalRectKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TrashRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct TrashGlobalRectKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

#Preview {
    TrayEditor()
}
