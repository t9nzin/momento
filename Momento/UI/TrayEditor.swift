import SwiftUI

struct TrayEditor: View {
    enum Mode: String, CaseIterable, Identifiable {
        case boring = "Folder"
        case custom = "Stamps"
        var id: String { rawValue }
    }

    struct CardItem: Identifiable, Equatable {
        let id = UUID()
        let imageName: String
    }

    private struct SlotPose {
        let offset: CGSize
        let rotation: Angle
    }

    @State private var mode: Mode = .custom

    @State private var cards: [CardItem] = [
        CardItem(imageName: "cardNoProblem"),
        CardItem(imageName: "cardKassian"),
        CardItem(imageName: "cardLandscape"),
        CardItem(imageName: "cardText")
    ]

    @State private var activeCardID: UUID?
    @State private var swipeOffset: CGFloat = 0
    @State private var titleText = "cargoworld"
    @State private var subtitleText = ""

    private let trayCorner: CGFloat = 36
    private let canvasHeight: CGFloat = 240

    var body: some View {
        ZStack {
            Color(red: 0.93, green: 0.93, blue: 0.94)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack(alignment: .top, spacing: 18) {
                    FolderCard()
                        .frame(width: 160)
                    FolderCard()
                        .frame(width: 160)
                    FolderCard()
                        .frame(width: 160)
                }
                .padding(.bottom, 12)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            libraryHeader
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 4)
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
        .onAppear {
            if activeCardID == nil {
                activeCardID = cards.first(where: { $0.imageName == "cardKassian" })?.id ?? cards.first?.id
            }
        }
    }

    private var libraryHeader: some View {
        HStack {
            headerCircleButton(systemName: "plus") { }
            Spacer()
            Text("Library")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
            headerCircleButton(systemName: "ellipsis") { }
        }
    }

    private func headerCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.75))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
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

    private var segmentedControl: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases) { option in
                let selected = mode == option
                Text(option.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : Color.white.opacity(0.55))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            if selected {
                                Capsule()
                                    .fill(Color.black)
                            }
                        }
                    )
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            mode = option
                        }
                    }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(red: 0.30, green: 0.30, blue: 0.32))
        )
        .frame(maxWidth: 240)
    }

    // MARK: - Canvas

    private var canvas: some View {
        ZStack {
            dottedBackground
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            ForEach(cards) { card in
                cardView(for: card)
            }
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
                    withAnimation(.snappy(duration: 0.28)) {
                        if value.translation.width < -threshold {
                            cycleActive(forward: true)
                        } else if value.translation.width > threshold {
                            cycleActive(forward: false)
                        }
                        swipeOffset = 0
                    }
                }
        )
    }

    private func slotPose(for cardID: UUID) -> SlotPose {
        guard let activeID = activeCardID,
              let activeIdx = cards.firstIndex(where: { $0.id == activeID }),
              let cardIdx = cards.firstIndex(where: { $0.id == cardID }) else {
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
        guard let activeID = activeCardID,
              let idx = cards.firstIndex(where: { $0.id == activeID }) else { return }
        let nextIdx = forward ? min(idx + 1, cards.count - 1)
                              : max(idx - 1, 0)
        activeCardID = cards[nextIdx].id
    }

    @ViewBuilder
    private func cardView(for card: CardItem) -> some View {
        let isActive = card.id == activeCardID
        let pose = slotPose(for: card.id)
        let liveX = pose.offset.width + swipeOffset
        let diff: Int = {
            guard let activeID = activeCardID,
                  let activeIdx = cards.firstIndex(where: { $0.id == activeID }),
                  let cardIdx = cards.firstIndex(where: { $0.id == card.id }) else {
                return 0
            }
            return cardIdx - activeIdx
        }()
        let baseOpacity: Double = abs(diff) > 2 ? 0 : (isActive ? 1.0 : 0.42)

        ZStack {
            cardImage(named: card.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 116, height: 168)
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

    private func cardImage(named name: String) -> Image {
        if let ui = UIImage(named: name) {
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
                    Text("Crop")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(.black)
            }

            Button(action: sendActiveCardToBack) {
                Text("Back")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
            }

            Button(action: bringActiveCardToFront) {
                Text("Front")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
        )
    }

    private func sendActiveCardToBack() {
        guard let activeID = activeCardID,
              let idx = cards.firstIndex(where: { $0.id == activeID }) else { return }
        let item = cards.remove(at: idx)
        cards.insert(item, at: 0)
    }

    private func bringActiveCardToFront() {
        guard let activeID = activeCardID,
              let idx = cards.firstIndex(where: { $0.id == activeID }) else { return }
        let item = cards.remove(at: idx)
        cards.append(item)
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
        HStack(spacing: 10) {
            sourcePill
            saveButton
        }
    }

    private var sourcePill: some View {
        HStack(spacing: 10) {
            Text("May 11, 2026")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.55))

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Text("tokyo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.45, blue: 0.95))
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.45, blue: 0.95))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white)
                .overlay(
                    Capsule().stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    private var saveButton: some View {
        Button(action: handleSave) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Stamp")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.black))
        }
    }

    private func handleSave() {
        print("Save tapped — title=\(titleText) subtitle=\(subtitleText)")
    }
}

#Preview {
    TrayEditor()
}
