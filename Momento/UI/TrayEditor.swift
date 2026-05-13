import SwiftUI
import SwiftData
import AVFoundation

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
            return "calendar"
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
    @State private var titleText = "cargoworld"
    @State private var subtitleText = ""
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

    @State private var sourceTab: SourceTab = .house
    @State private var sourceMorphProgress: CGFloat = 0

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
            photoAssets: peeks
        )
        .frame(width: 160)
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
                .background(
                    RoundedRectangle(cornerRadius: trayCorner, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 6)
                )
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
        Button(action: action) {
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

            canvas
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            floatingControlPill
                .padding(.bottom, 18)

            titleBlock
                .padding(.bottom, 16)

            bottomBar
                .padding(.horizontal, 14)
                .padding(.bottom, 18)
        }
    }

    // MARK: - Drag handle

    private var dragHandle: some View {
        Capsule()
            .fill(Color.black.opacity(0.18))
            .frame(width: 38, height: 5)
    }

    // MARK: - Segmented control

    private static let pillBaseColor    = Color(red:  83/255.0, green:  83/255.0, blue:  90/255.0)
    private static let pillInactiveText = Color(red: 154/255.0, green: 154/255.0, blue: 159/255.0)
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

                movingBubble(width: segW, height: segH)
                    .offset(x: bubbleX, y: inset)
                    .animation(.spring(response: 0.46, dampingFraction: 0.62), value: mode)

                HStack(spacing: 0) {
                    ForEach(Mode.allCases) { option in
                        let selected = (mode == option)
                        Text(option.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selected ? Color.white : Self.pillInactiveText)
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
        .frame(maxWidth: 240)
    }

    private func selectMode(_ option: Mode) {
        guard mode != option else { return }
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
        let m = Double(morphProgress)
        return Capsule()
            .fill(Self.pillActiveBubble)
            .frame(width: width, height: height)
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.7
                    )
            )
            .overlay(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(width: width, height: height)
                    .opacity(0.42 * m)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.28 + 0.12 * m),
                    radius: 6 + 6 * morphProgress,
                    x: 0,
                    y: 3 + 2 * morphProgress)
            .scaleEffect(x: 1.0 + 0.08 * morphProgress,
                         y: 1.0 - 0.06 * morphProgress)
            .blur(radius: 0.7 * morphProgress)
            .opacity(1.0 - 0.15 * m)
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
        let cardHeight: CGFloat = 168
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

        ZStack {
            cardImage(for: stamp)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 116, height: 168)
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
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(isActive ? 0.16 : 0.05),
                        radius: isActive ? 10 : 4,
                        x: 0, y: isActive ? 6 : 2)
                .opacity(baseOpacity)

            if isActive {
                cornerHandles
                    .frame(width: 116 + 6, height: 168 + 6)
            }
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

    // MARK: - Selection corner handles

    private var cornerHandles: some View {
        GeometryReader { geo in
            let s = geo.size
            let length: CGFloat = 12
            let thickness: CGFloat = 1.6
            ZStack {
                cornerBracket(length: length, thickness: thickness, corner: .topLeading)
                    .position(x: 0, y: 0)
                cornerBracket(length: length, thickness: thickness, corner: .topTrailing)
                    .position(x: s.width, y: 0)
                cornerBracket(length: length, thickness: thickness, corner: .bottomLeading)
                    .position(x: 0, y: s.height)
                cornerBracket(length: length, thickness: thickness, corner: .bottomTrailing)
                    .position(x: s.width, y: s.height)
            }
        }
    }

    private func cornerBracket(length: CGFloat = 11, thickness: CGFloat = 1.6,
                               corner: UnitPoint) -> some View {
        let color = Color.black
        return ZStack {
            // horizontal arm
            Rectangle()
                .fill(color)
                .frame(width: length, height: thickness)
                .offset(
                    x: (corner == .topLeading || corner == .bottomLeading) ? length/2 : -length/2,
                    y: 0
                )
            // vertical arm
            Rectangle()
                .fill(color)
                .frame(width: thickness, height: length)
                .offset(
                    x: 0,
                    y: (corner == .topLeading || corner == .topTrailing) ? length/2 : -length/2
                )
        }
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
                Text("Stamp")
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
                .shadow(color: .black.opacity(0.045), radius: 8, x: 0, y: 3)
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
            TextField("title", text: $titleText)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)

            TextField("add subtitle", text: $subtitleText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.black.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
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
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Stamp")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(height: 44)
            .background(Capsule().fill(Color.black))
            .opacity(showStampPunch ? 0.55 : 1.0)
        }
        .disabled(showStampPunch)
    }

    private func handleSave() {
        guard centeredFolder != nil else { return }
        guard !showStampPunch else { return }
        // Present immediately. The camera handles permission + simulator
        // internally so the cover never blocks waiting for hardware.
        sharedCamera.requestAuthorizationAndStart()
        showStampPunch = true
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

#Preview {
    TrayEditor()
}
