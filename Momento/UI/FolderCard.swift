import SwiftUI

/// Home-screen folder card. Layout mirrors the Framer "Photos Folder"
/// component pixel-for-pixel relative to a 188×190 folder. Tapping the card
/// toggles between Default and Hover variants — polaroids fan outward.
struct FolderCard: View {
    var title: String = "Japan 2024"
    var photoCount: Int = 83
    var leftSticker: String = "FlagSticker"
    var leftStickerScale: CGFloat = 1.0
    var rightSticker: String = "FlagSticker"
    var rightStickerScale: CGFloat = 1.0
    var extraSticker: String? = nil
    var isExpanded: Bool = false
    /// Override the three peek-photo assets. Order: [center, left, right].
    var photoAssets: [String]? = nil

    private struct PhotoLayout {
        let asset: String
        let xDefault: CGFloat
        let yDefault: CGFloat
        let rotationDefault: Double
        let xHover: CGFloat
        let yHover: CGFloat
        let rotationHover: Double
    }

    // Positions/rotations mirror the Framer "Photos Folder" component.
    // Offsets are normalized by folder width (188 in Framer). y values include
    // the folderYNudge so photos shift with the folder body.
    private let photos: [PhotoLayout] = [
        PhotoLayout(asset: "Photo2",
                    xDefault: -0.020, yDefault: -0.190, rotationDefault:   4,
                    xHover:    0.000, yHover:   -0.400, rotationHover:    -2),
        PhotoLayout(asset: "Photo1",
                    xDefault: -0.330, yDefault: -0.080, rotationDefault: -22,
                    xHover:   -0.500, yHover:   -0.260, rotationHover:   -32),
        PhotoLayout(asset: "Photo3",
                    xDefault:  0.330, yDefault: -0.070, rotationDefault:  18,
                    xHover:    0.500, yHover:   -0.250, rotationHover:    28),
    ]

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let w = geo.size.width
                let folderW = w * folderWidthRatio
                ZStack {
                    ForEach(Array(photos.enumerated()), id: \.offset) { idx, p in
                        let x = isExpanded ? p.xHover : p.xDefault
                        let y = isExpanded ? p.yHover : p.yDefault
                        let r = isExpanded ? p.rotationHover : p.rotationDefault
                        let asset = (photoAssets != nil && idx < (photoAssets?.count ?? 0))
                            ? photoAssets![idx] : p.asset
                        PeekPhoto(assetName: asset, width: folderW * polaroidSize)
                            .rotationEffect(.degrees(r))
                            .offset(x: folderW * x, y: folderW * y)
                    }

                    let folderYNudge = folderW * 0.06
                    let folderJump = isExpanded ? -folderW * 0.05 : 0
                    let folderScale = isExpanded ? 1.05 : 1.0

                    ZStack {
                        ReplicaFolderFront(material: .ultraThinMaterial, isHighlighted: isExpanded)
                            .frame(width: folderW)
                            .opacity(0.99)
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 6)

                        Image(leftSticker)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: folderW * 0.250 * leftStickerScale)
                            .rotationEffect(.degrees(-8))
                            .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                            .offset(x: -folderW * 0.255, y: -folderW * 0.150)

                        Image(rightSticker)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: folderW * 0.293 * rightStickerScale)
                            .rotationEffect(.degrees(7))
                            .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                            .offset(x: folderW * 0.231, y: folderW * 0.013)

                        if let extraSticker {
                            Image(extraSticker)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: folderW * 0.250)
                                .rotationEffect(.degrees(-4))
                                .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                                .offset(x: -folderW * 0.175, y: folderW * 0.120)
                        }
                    }
                    .scaleEffect(folderScale)
                    .offset(y: folderYNudge + folderJump)
                }
                .frame(width: w, height: geo.size.height, alignment: .center)
            }
            .aspectRatio(1.25, contentMode: .fit)

            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text("\(photoCount) \(photoCount == 1 ? "photo" : "photos")")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(red: 110/255, green: 110/255, blue: 115/255))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(red: 230/255, green: 230/255, blue: 232/255), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.42, dampingFraction: 0.72), value: isExpanded)
    }

    private var folderWidthRatio: CGFloat { 0.72 }
    private var polaroidSize: CGFloat { 0.479 }
}

private struct PeekPhoto: View {
    let assetName: String
    let width: CGFloat

    var body: some View {
        // From Framer: 90×90 white tile, 18px outer radius, 10px white border
        // around a 70×70 image with 8px inner radius.
        let inner = width * (70.0 / 90.0)
        let outerRadius = width * (18.0 / 90.0)
        let innerRadius = inner * (8.0 / 70.0)
        ZStack {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(Color.white)
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: inner, height: inner)
                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
        }
        .frame(width: width, height: width)
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

/// Folder front view. Uses `FolderOutlineShape` (a literal trace of the user's
/// SVG) for the silhouette, filled with the exact Framer source colors plus
/// two near-white capsule lines at the bottom.
private struct ReplicaFolderFront: View {
    var material: Material
    var isHighlighted: Bool = false

    // From Framer "Photos Folder > Default > Folder":
    //   backgroundColor=rgba(252,252,252,0.7), borderRadius=14, no stroke.
    private let bodyFill = Color.white.opacity(0.42)

    // Framer lines: 168 wide × 2 tall, borderRadius 98 (capsule), centerX 50%.
    //   line 1 (bottom: 40) — backgroundColor=rgba(252,252,252,0.25)
    //   line 2 (bottom: 27) — backgroundColor=rgba(255,255,255,0.25)
    // Folder is 188×190 in Framer; ratios below are reused regardless of the
    // SVG-derived aspect of the silhouette.
    private let lineWidthRatio: CGFloat = 148.0 / 188.0
    private let line1BottomRatio: CGFloat = 40.0 / 190.0
    private let line2BottomRatio: CGFloat = 27.0 / 190.0
    private let lineHeight: CGFloat = 2
    private let line1Fill = Color(red: 252/255, green: 252/255, blue: 252/255).opacity(0.25)
    private let line2Fill = Color.white.opacity(0.25)

    var body: some View {
        FolderOutlineShape()
            .fill(material)
            .overlay {
                FolderOutlineShape()
                    .fill(bodyFill)
            }
            // Soft outer rim shadow — gives the folder physical presence.
            .overlay {
                FolderOutlineShape()
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
                    .blur(radius: 1.2)
            }
            // Bright directional inner highlight on the selected folder only.
            .overlay {
                if isHighlighted {
                    FolderOutlineShape()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.95), location: 0.0),
                                    .init(color: Color.white.opacity(0.75), location: 0.18),
                                    .init(color: Color(red: 1.00, green: 0.78, blue: 0.82).opacity(0.65), location: 0.55),
                                    .init(color: Color(red: 0.78, green: 0.78, blue: 0.95).opacity(0.65), location: 0.85),
                                    .init(color: Color.white.opacity(0.40), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.6
                        )
                        .transition(.opacity)
                }
            }
            // Inner glow: a second thinner white stroke set slightly inside
            // the rim creates the frosted-glass bevel feel.
            .overlay {
                FolderOutlineShape()
                    .stroke(Color.white.opacity(0.55), lineWidth: 0.6)
                    .blur(radius: 0.4)
                    .padding(0.8)
            }
            // Subtle dark hairline for definition against light backgrounds.
            .overlay {
                FolderOutlineShape()
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
            }
            // Diagonal color wash bleeding from the edges — pink top-right,
            // lavender bottom-left — for the iridescent glass look.
            .overlay {
                FolderOutlineShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.85, blue: 0.88).opacity(0.06),
                                .clear,
                                Color(red: 0.85, green: 0.85, blue: 1.00).opacity(0.06)
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let lineW = w * lineWidthRatio

                    Capsule()
                        .fill(line1Fill)
                        .frame(width: lineW, height: lineHeight)
                        .position(x: w / 2, y: h - h * line1BottomRatio - lineHeight / 2)

                    Capsule()
                        .fill(line2Fill)
                        .frame(width: lineW, height: lineHeight)
                        .position(x: w / 2, y: h - h * line2BottomRatio - lineHeight / 2)
                }
            }
            .aspectRatio(FolderOutlineShape.viewBox.width / FolderOutlineShape.viewBox.height,
                         contentMode: .fit)
    }
}

/// 1:1 trace of the SVG path the user supplied (file (2).svg). Coordinates
/// match the SVG path data in the 212×152 design space; the path is scaled to
/// fit the rect at draw time.
private struct FolderOutlineShape: Shape {
    static let viewBox = CGSize(width: 212, height: 152)

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / Self.viewBox.width
        let sy = rect.height / Self.viewBox.height

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: p(195.000000, 152.000000))
        path.addCurve(
            to: p(19.808563, 151.759094),
            control1: p(136.645767, 152.000000),
            control2: p(78.291542, 152.000000)
        )
        path.addCurve(
            to: p(12.329716, 142.554993),
            control1: p(17.125879, 148.546875),
            control2: p(12.849835, 145.847595)
        )
        path.addCurve(
            to: p(9.011496, 107.815910),
            control1: p(10.518085, 131.086502),
            control2: p(9.969906, 119.415642)
        )
        path.addCurve(
            to: p(6.031728, 70.030632),
            control1: p(7.971160, 95.224640),
            control2: p(6.936669, 82.632103)
        )
        path.addCurve(
            to: p(2.924142, 24.748787),
            control1: p(4.948039, 54.940056),
            control2: p(4.046476, 39.836288)
        )
        path.addCurve(
            to: p(1.000000, 13.000000),
            control1: p(2.500000, 21.000000),
            control2: p(1.000000, 17.500000)
        )
        path.addCurve(
            to: p(13.000000, 1.000000),
            control1: p(1.000000, 6.500000),
            control2: p(6.500000, 1.000000)
        )
        path.addCurve(
            to: p(76.000000, 1.000000),
            control1: p(34.000000, 1.000000),
            control2: p(55.000000, 1.000000)
        )
        path.addCurve(
            to: p(93.000000, 13.000000),
            control1: p(82.500000, 1.000000),
            control2: p(88.000000, 7.500000)
        )
        path.addCurve(
            to: p(109.500000, 18.150000),
            control1: p(97.500000, 17.200000),
            control2: p(103.500000, 18.100000)
        )
        path.addCurve(
            to: p(195.952744, 17.988735),
            control1: p(137.110550, 17.867342),
            control2: p(166.532196, 18.014229)
        )
        path.addCurve(
            to: p(212.000000, 26.000000),
            control1: p(204.800000, 17.988735),
            control2: p(212.000000, 21.600000)
        )
        path.addCurve(
            to: p(208.992126, 53.451942),
            control1: p(212.000000, 35.000000),
            control2: p(209.700000, 43.000000)
        )
        path.addCurve(
            to: p(206.938065, 83.507423),
            control1: p(208.340744, 63.472729),
            control2: p(207.745605, 73.498810)
        )
        path.addCurve(
            to: p(202.989075, 129.144379),
            control1: p(205.710052, 98.726898),
            control2: p(204.348083, 113.935806)
        )
        path.addCurve(
            to: p(194.413681, 151.382187),
            control1: p(202.254929, 137.360092),
            control2: p(203.933365, 146.540604)
        )
        path.addCurve(
            to: p(195.000000, 152.000000),
            control1: p(194.609116, 151.588120),
            control2: p(194.804565, 151.794067)
        )
        path.closeSubpath()
        return path
    }
}
