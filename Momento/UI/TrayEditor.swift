import SwiftUI

struct TrayEditor: View {
    enum Mode: String, CaseIterable, Identifiable {
        case boring = "Boring"
        case custom = "Custom"
        var id: String { rawValue }
    }

    struct CardItem: Identifiable, Equatable {
        let id = UUID()
        let imageName: String
        var offset: CGSize = .zero
        var rotation: Angle = .degrees(0)
    }

    @State private var mode: Mode = .custom

    @State private var cards: [CardItem] = [
        CardItem(imageName: "cardNoProblem",
                 offset: CGSize(width: -118, height: 10),
                 rotation: .degrees(-4)),
        CardItem(imageName: "cardLandscape",
                 offset: CGSize(width: 86, height: 14),
                 rotation: .degrees(1)),
        CardItem(imageName: "cardText",
                 offset: CGSize(width: 118, height: 2),
                 rotation: .degrees(5)),
        CardItem(imageName: "cardKassian",
                 offset: CGSize(width: 0, height: -4),
                 rotation: .degrees(-8))
    ]

    @State private var activeCardID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var titleText = "cargoworld"
    @State private var subtitleText = ""

    private let trayCorner: CGFloat = 36
    private let canvasHeight: CGFloat = 240

    var body: some View {
        ZStack {
            Color(red: 0.93, green: 0.93, blue: 0.94)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                trayContent
                    .background(
                        RoundedRectangle(cornerRadius: trayCorner, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 6)
                    )
                    .padding(.horizontal, 10)

                Spacer(minLength: 10)
            }
        }
        .onAppear {
            if activeCardID == nil {
                activeCardID = cards.last?.id
            }
        }
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

            Spacer(minLength: 16)

            titleBlock

            Spacer(minLength: 16)

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

            ForEach(orderedCards) { card in
                cardView(for: card)
            }
        }
        .frame(height: canvasHeight)
    }

    private var orderedCards: [CardItem] {
        guard let activeID = activeCardID,
              let activeIdx = cards.firstIndex(where: { $0.id == activeID }) else {
            return cards
        }
        var rearranged = cards
        let active = rearranged.remove(at: activeIdx)
        rearranged.append(active)
        return rearranged
    }

    @ViewBuilder
    private func cardView(for card: CardItem) -> some View {
        let isActive = card.id == activeCardID
        let liveOffset: CGSize = isActive && isDragging
            ? CGSize(width: card.offset.width + dragOffset.width,
                     height: card.offset.height + dragOffset.height)
            : card.offset

        ZStack {
            cardImage(named: card.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth(for: card), height: cardHeight(for: card))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(isActive ? 0.16 : 0.05),
                        radius: isActive ? 10 : 4,
                        x: 0, y: isActive ? 6 : 2)
                .opacity(isActive ? 1.0 : 0.42)

            if isActive {
                cornerHandles
                    .frame(width: cardWidth(for: card) + 6,
                           height: cardHeight(for: card) + 6)
            }
        }
        .rotationEffect(card.rotation)
        .offset(liveOffset)
        .zIndex(isActive ? 100 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                activeCardID = card.id
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        activeCardID = card.id
                        dragStartOffset = card.offset
                    }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    if let idx = cards.firstIndex(where: { $0.id == card.id }) {
                        cards[idx].offset = CGSize(
                            width: dragStartOffset.width + value.translation.width,
                            height: dragStartOffset.height + value.translation.height
                        )
                    }
                    dragOffset = .zero
                    isDragging = false
                }
        )
    }

    private func cardWidth(for card: CardItem) -> CGFloat {
        card.id == activeCardID ? 130 : 116
    }

    private func cardHeight(for card: CardItem) -> CGFloat {
        card.id == activeCardID ? 188 : 168
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
            Text("Source")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.55))

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Text("cargoworld")
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
            Text("Save")
                .font(.system(size: 15, weight: .semibold))
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
