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
                let displayAssets = Array(photos.enumerated()).map { idx, p in
                    (photoAssets != nil && idx < (photoAssets?.count ?? 0))
                        ? photoAssets![idx] : p.asset
                }
                ZStack {
                    let folderYNudge = folderW * 0.06
                    let folderJump = isExpanded ? -folderW * 0.05 : 0
                    let folderScale = isExpanded ? 1.05 : 1.0

                    SVGGlassFolderReplica(photoAssets: displayAssets, width: folderW * 1.24)
                        .scaleEffect(folderScale)
                        .offset(y: folderYNudge + folderJump)

                    if !isExpanded {
                        ZStack {
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

                Text("\(photoCount) \(photoCount == 1 ? "stamp" : "stamps")")
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
        // White stamp tile around a 70×70 image, scaled from the original
        // 90×90 Framer peek-photo proportions.
        let inner = width * (70.0 / 90.0)
        let outerShape = PostageStampShape(bite: width * 0.060, spacing: width * 0.155)
        let innerShape = PostageStampShape(bite: inner * 0.052, spacing: inner * 0.155)

        ZStack {
            outerShape
                .fill(Color.white)
                .overlay(
                    outerShape
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.4)
                )

            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: inner, height: inner)
                .clipShape(innerShape)
        }
        .frame(width: width, height: width)
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

private struct SVGGlassFolderReplica: View {
    let photoAssets: [String]
    let width: CGFloat

    private var frontHeight: CGFloat { width * (104.0 / 184.0) }
    private var backWidth: CGFloat { width * 0.98 }
    private var backHeight: CGFloat { backWidth * (75.0 / 181.0) }
    private var stampYOffset: CGFloat { -width * 0.095 }
    private var frontYOffset: CGFloat { width * 0.13 }
    private var backYOffset: CGFloat { -width * 0.12 }

    var body: some View {
        ZStack {
            backCoverLayer

            folderStamps
                .offset(y: stampYOffset)

            frontCoverBase

            frontGlassColor

            frostedStampDiffusion

            frontCoverPolish

            textureTabs
        }
        .frame(width: width, height: width * 0.92)
    }

    private var backCoverLayer: some View {
        SVGBackCoverShape()
            .fill(backFill)
            .frame(width: backWidth, height: backHeight)
            .overlay {
                SVGBackCoverShape()
                    .stroke(Color.black.opacity(0.070), lineWidth: 1.15)
                    .blur(radius: 0.85)
                    .offset(y: 0.6)
            }
            // Bright rim around the back cover — kept all-white so the
            // right side doesn't darken into the diagonal-gradient endpoint
            // and read as a black corner under the mask.
            .overlay {
                SVGBackCoverShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                Color.white.opacity(0.86),
                                Color.white.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 5.8
                    )
                    .clipShape(SVGBackCoverShape())
            }
            // Extend the visible region down so the right curve of the back
            // cover reaches the front cover instead of leaving a gap.
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                        .frame(height: backHeight * 0.86)
                    Spacer(minLength: 0)
                }
                .frame(width: backWidth, height: backHeight)
            }
            .shadow(color: .black.opacity(0.075), radius: 12, x: 0, y: 6)
            .offset(y: backYOffset)
    }

    private var frontCoverBase: some View {
        SVGFrontCoverShape()
            .fill(frontFill)
            .frame(width: width, height: frontHeight)
            .overlay {
                SVGFrontCoverShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.925, blue: 0.72).opacity(0.32),
                                Color.white.opacity(0.58),
                                Color(red: 0.80, green: 0.965, blue: 0.985).opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .black.opacity(0.035), radius: 2, x: 0, y: -1)
            .offset(y: frontYOffset)
    }

    private var frontGlassColor: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.70, blue: 0.34).opacity(0.31),
                    Color(red: 1.0, green: 0.90, blue: 0.68).opacity(0.15),
                    Color.clear
                ],
                center: UnitPoint(x: 0.24, y: 0.42),
                startRadius: width * 0.02,
                endRadius: width * 0.42
            )

            RadialGradient(
                colors: [
                    Color(red: 0.50, green: 0.92, blue: 0.94).opacity(0.25),
                    Color(red: 0.75, green: 0.98, blue: 0.98).opacity(0.12),
                    Color.clear
                ],
                center: UnitPoint(x: 0.72, y: 0.42),
                startRadius: width * 0.02,
                endRadius: width * 0.38
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.68),
                    Color.white.opacity(0.30),
                    Color.clear
                ],
                center: UnitPoint(x: 0.50, y: 0.78),
                startRadius: width * 0.03,
                endRadius: width * 0.34
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.52),
                    Color.white.opacity(0.28),
                    Color.white.opacity(0.70)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: width, height: frontHeight)
        .clipShape(SVGFrontCoverShape())
        .offset(y: frontYOffset)
        .allowsHitTesting(false)
    }

    private var frostedStampDiffusion: some View {
        ZStack {
            folderStamps
                .offset(y: stampYOffset + width * 0.02)
        }
        .frame(width: width, height: width * 0.92)
        .blur(radius: 15)
        .saturation(0.16)
        .contrast(0.48)
        .opacity(0.055)
        .mask {
            SVGFrontCoverShape()
                .frame(width: width, height: frontHeight)
                .offset(y: frontYOffset)
        }
        .allowsHitTesting(false)
    }

    private var frontCoverPolish: some View {
        SVGFrontCoverShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.58),
                        Color.white.opacity(0.20),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: frontHeight)
            .overlay {
                SVGFrontCoverShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.98),
                                Color.white.opacity(0.92),
                                Color.white.opacity(0.50)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.65
                    )
                    .clipShape(SVGFrontCoverShape())
            }
            .overlay {
                SVGFrontCoverShape()
                    .stroke(Color.black.opacity(0.042), lineWidth: 1.0)
                    .blur(radius: 0.85)
                    .offset(y: 0.85)
            }
            .overlay {
                SVGFrontCoverShape()
                    .stroke(Color.white.opacity(0.96), lineWidth: 1.15)
                    .blur(radius: 0.18)
                    .offset(x: -0.45, y: -0.50)
                    .clipShape(SVGFrontCoverShape())
            }
            .shadow(color: .black.opacity(0.095), radius: 20, x: 0, y: 11)
            .shadow(color: .black.opacity(0.035), radius: 3, x: 0, y: 1)
            .shadow(color: .white.opacity(0.76), radius: 7, x: -2, y: -2)
            .offset(y: frontYOffset)
    }

    private var textureTabs: some View {
        FolderTextureLines()
            .frame(width: width * (43.0 / 184.0), height: width * (9.0 / 184.0))
            .opacity(1.0)
            .offset(y: width * 0.335)
    }

    private var folderStamps: some View {
        ZStack {
            // Left stamp — sits slightly above and to the left of center,
            // tilted counter-clockwise, tucked behind the right stamp.
            if photoAssets.indices.contains(0) {
                GlassPeekStamp(assetName: photoAssets[0],
                               width: width * 0.46,
                               height: (width * 0.46) / StampVisualMetrics.aspectRatio)
                    .rotationEffect(.degrees(-7))
                    .offset(x: -width * 0.16, y: -width * 0.02)
                    .zIndex(1)
            }

            // Right stamp — slightly lower and to the right, tilted
            // clockwise, sits in front of the left stamp.
            if photoAssets.indices.contains(1) {
                GlassPeekStamp(assetName: photoAssets[1],
                               width: width * 0.48,
                               height: (width * 0.48) / StampVisualMetrics.aspectRatio)
                    .rotationEffect(.degrees(5))
                    .offset(x: width * 0.16, y: width * 0.055)
                    .zIndex(2)
            }
        }
    }

    private var frontFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.97, blue: 0.88).opacity(0.99),
                Color(red: 0.998, green: 0.998, blue: 0.985).opacity(0.97),
                Color(red: 0.88, green: 0.965, blue: 0.985).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.90),
                Color(red: 0.968, green: 0.988, blue: 0.988).opacity(0.70),
                Color(red: 0.86, green: 0.91, blue: 0.91).opacity(0.44)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct GlassPeekStamp: View {
    let assetName: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let shape = PostageStampShape(bite: min(width, height) * 0.060,
                                      spacing: min(width, height) * 0.150)

        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipShape(shape)
            .overlay {
                shape.stroke(Color.white.opacity(0.32), lineWidth: 0.45)
            }
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
    }
}

private struct FolderTextureLines: View {
    var body: some View {
        VStack(spacing: 2.2) {
            textureLine(opacity: 0.96)
            textureLine(opacity: 0.82)
        }
        .shadow(color: .black.opacity(0.045), radius: 1.2, x: 0, y: 0.8)
    }

    private func textureLine(opacity: Double) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(opacity),
                        Color(red: 0.78, green: 0.83, blue: 0.82).opacity(0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.68), lineWidth: 0.35)
            }
    }
}

private struct SVGFrontCoverShape: Shape {
    static let viewBox = CGSize(width: 184, height: 104)

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / Self.viewBox.width
        let sy = rect.height / Self.viewBox.height

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: p(1.9209, 38))
        path.addLine(to: p(0.528863, 17.1195))
        path.addCurve(to: p(0.71124, 13.9031),
                      control1: p(0.45716, 16.0439),
                      control2: p(0.518415, 14.9637))
        path.addCurve(to: p(11.4477, 1.36023),
                      control1: p(1.7677, 8.0926),
                      control2: p(5.86973, 3.30041))
        path.addLine(to: p(12.2184, 1.09216))
        path.addCurve(to: p(15.7234, 0.5),
                      control1: p(13.3454, 0.700165),
                      control2: p(14.5302, 0.5))
        path.addLine(to: p(81.4209, 0.5))
        path.addLine(to: p(81.983, 0.53513))
        path.addCurve(to: p(93.4509, 7.26882),
                      control1: p(86.6592, 0.827394),
                      control2: p(90.9172, 3.32761))
        path.addCurve(to: p(94.1597, 8.83578),
                      control1: p(93.7625, 7.75365),
                      control2: p(94.0014, 8.2816))
        path.addLine(to: p(96.5111, 17.0659))
        path.addCurve(to: p(97.5879, 19.8341),
                      control1: p(96.7837, 18.0199),
                      control2: p(97.1442, 18.9466))
        path.addLine(to: p(98.1733, 21.0048))
        path.addCurve(to: p(98.7753, 21.9253),
                      control1: p(98.3378, 21.3338),
                      control2: p(98.5398, 21.6427))
        path.addCurve(to: p(104.272, 24.5),
                      control1: p(100.135, 23.5567),
                      control2: p(102.149, 24.5))
        path.addLine(to: p(168.32, 24.5))
        path.addCurve(to: p(172.364, 25.3001),
                      control1: p(169.707, 24.5),
                      control2: p(171.081, 24.7718))
        path.addCurve(to: p(181.801, 34.4799),
                      control1: p(176.573, 27.0331),
                      control2: p(179.952, 30.3206))
        path.addLine(to: p(182.221, 35.4262))
        path.addCurve(to: p(182.921, 38.7222),
                      control1: p(182.683, 36.4639),
                      control2: p(182.921, 37.5867))
        path.addLine(to: p(182.921, 42.5))
        path.addLine(to: p(182.421, 48.5))
        path.addLine(to: p(180.421, 66.5))
        path.addLine(to: p(178.658, 81.9264))
        path.addCurve(to: p(177.761, 85.98),
                      control1: p(178.5, 83.3051),
                      control2: p(178.2, 84.6636))
        path.addLine(to: p(176.855, 88.6968))
        path.addCurve(to: p(175.687, 91.1614),
                      control1: p(176.567, 89.5624),
                      control2: p(176.175, 90.39))
        path.addLine(to: p(174.798, 92.5696))
        path.addCurve(to: p(162.684, 102.208),
                      control1: p(171.964, 97.0574),
                      control2: p(167.694, 100.454))
        path.addCurve(to: p(158.023, 103),
                      control1: p(161.186, 102.732),
                      control2: p(159.61, 103))
        path.addLine(to: p(31.188, 103))
        path.addCurve(to: p(16.8727, 98.8299),
                      control1: p(26.0939, 103),
                      control2: p(21.0006, 101.815))
        path.addCurve(to: p(12.9209, 95.5),
                      control1: p(15.4022, 97.7666),
                      control2: p(13.9691, 96.6098))
        path.addCurve(to: p(8.5761, 89.2013),
                      control1: p(11.3288, 93.8143),
                      control2: p(9.76869, 91.3302))
        path.addCurve(to: p(5.87937, 80.3068),
                      control1: p(7.04621, 86.4704),
                      control2: p(6.23818, 83.4164))
        path.addLine(to: p(4.9209, 72))
        path.addLine(to: p(3.9209, 58.5))
        path.addLine(to: p(1.9209, 38))
        path.closeSubpath()
        return path
    }
}

private struct SVGBackCoverShape: Shape {
    static let viewBox = CGSize(width: 181, height: 75)

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / Self.viewBox.width
        let sy = rect.height / Self.viewBox.height

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: p(175.826, 73.9749))
        path.addLine(to: p(177.326, 61.4749))
        path.addLine(to: p(178.826, 45.4749))
        path.addLine(to: p(179.826, 34.4749))
        path.addLine(to: p(180.101, 30.0781))
        path.addCurve(to: p(179.239, 23.0321),
                      control1: p(180.25, 27.6964),
                      control2: p(179.958, 25.3077))
        path.addLine(to: p(178.888, 21.9217))
        path.addCurve(to: p(159.992, 2.57095),
                      control1: p(176.019, 12.8369),
                      control2: p(169.006, 5.65476))
        path.addCurve(to: p(150.395, 0.956105),
                      control1: p(156.902, 1.51398),
                      control2: p(153.661, 0.968521))
        path.addLine(to: p(30.489, 0.500187))
        path.addCurve(to: p(17.7932, 3.3028),
                      control1: p(26.1018, 0.483506),
                      control2: p(21.7656, 1.44073))
        path.addCurve(to: p(3.3234, 18.0195),
                      control1: p(11.363, 6.31697),
                      control2: p(6.22836, 11.5392))
        path.addLine(to: p(2.9344, 18.8873))
        path.addCurve(to: p(0.83852, 26.3761),
                      control1: p(1.86818, 21.2658),
                      control2: p(1.16182, 23.7897))
        path.addCurve(to: p(0.589297, 34.5972),
                      control1: p(0.497711, 29.1025),
                      control2: p(0.414269, 31.855))
        path.addLine(to: p(1.82617, 53.9749))
        path.addLine(to: p(1.82617, 73.9749))
        path.closeSubpath()
        return path
    }
}

/// Folder front view. Uses `FolderOutlineShape` (a literal trace of the user's
/// SVG) for the silhouette, filled with the exact Framer source colors plus
/// two near-white capsule lines at the bottom.
private struct ReplicaFolderFront: View {
    // Visible width of the bright porcelain rim around the silhouette.
    // The inner body is inset by this amount so the rim shows through.
    private let rimWidth: CGFloat = 5.0

    // Inner body fill — deliberately off-white cream so the bright rim
    // reads with strong contrast and the warm peach glow has somewhere
    // to land.
    private let bodyBaseColor = Color(red: 0.945, green: 0.940, blue: 0.925)

    // Two grip capsules at the bottom of the front cover. Ratios mirror
    // the Framer 188×190 reference box.
    private let lineWidthRatio: CGFloat = 148.0 / 188.0
    private let line1BottomRatio: CGFloat = 40.0 / 190.0
    private let line2BottomRatio: CGFloat = 27.0 / 190.0
    private let lineHeight: CGFloat = 2.6

    var body: some View {
        ZStack {
            rim
            innerBody
                .padding(rimWidth)
            gripLines
        }
        .aspectRatio(FolderOutlineShape.viewBox.width / FolderOutlineShape.viewBox.height,
                     contentMode: .fit)
    }

    // The thick bright rim — outer silhouette filled with a top-weighted
    // white gradient and capped with a thin dark hairline at the edge.
    private var rim: some View {
        FolderOutlineShape()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.94), location: 0.00),
                        .init(color: Color.white.opacity(1.00), location: 0.15),
                        .init(color: Color.white.opacity(0.97), location: 0.50),
                        .init(color: Color.white.opacity(0.92), location: 0.85),
                        .init(color: Color(red: 0.93, green: 0.93, blue: 0.92), location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                FolderOutlineShape()
                    .stroke(Color.black.opacity(0.10), lineWidth: 0.6)
            }
    }

    // Inset interior — cream base + peach glow + aqua tint + bottom depth
    // shading + back-tab recess + an inner hairline at the seam with the rim.
    private var innerBody: some View {
        FolderOutlineShape()
            .fill(bodyBaseColor)
            // Warm peach glow on the upper-left — light bleeding through
            // from the stamps tucked behind the front cover.
            .overlay {
                GeometryReader { geo in
                    FolderOutlineShape()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.56, blue: 0.22).opacity(0.55),
                                    Color(red: 1.0, green: 0.76, blue: 0.46).opacity(0.30),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.27, y: 0.36),
                                startRadius: geo.size.width * 0.03,
                                endRadius: geo.size.width * 0.68
                            )
                        )
                }
            }
            // Cool aqua tint on the upper-right balances the warm side.
            .overlay {
                GeometryReader { geo in
                    FolderOutlineShape()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.48, green: 0.92, blue: 0.96).opacity(0.28),
                                    Color(red: 0.72, green: 0.97, blue: 0.98).opacity(0.12),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.72, y: 0.42),
                                startRadius: geo.size.width * 0.02,
                                endRadius: geo.size.width * 0.48
                            )
                        )
                }
            }
            // Vertical depth shading — body recedes toward the base.
            .overlay {
                FolderOutlineShape()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0.00),
                                .init(color: Color.clear, location: 0.45),
                                .init(color: Color.black.opacity(0.035), location: 0.80),
                                .init(color: Color.black.opacity(0.090), location: 1.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            // Back-tab area subtly recedes — darker tint on the top slice
            // above the front-cover leading edge.
            .overlay {
                GeometryReader { geo in
                    let h = geo.size.height
                    let frontTopFrac: CGFloat = 18.0 / 152.0

                    FolderOutlineShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.12),
                                    Color.black.opacity(0.055),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .mask {
                            VStack(spacing: 0) {
                                Rectangle()
                                    .frame(height: h * frontTopFrac + h * 0.020)
                                Spacer(minLength: 0)
                            }
                        }
                }
            }
            // Inner hairline along the seam between body and rim — gives
            // the rim a defined inside edge.
            .overlay {
                FolderOutlineShape()
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.55)
                    .blur(radius: 0.35)
            }
    }

    private var gripLines: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lineW = w * lineWidthRatio

            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.16), radius: 0.7, x: 0, y: 0.4)
                .frame(width: lineW, height: lineHeight)
                .position(x: w / 2,
                          y: h - h * line1BottomRatio - lineHeight / 2)

            Capsule()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.16), radius: 0.7, x: 0, y: 0.4)
                .frame(width: lineW, height: lineHeight)
                .position(x: w / 2,
                          y: h - h * line2BottomRatio - lineHeight / 2)
        }
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
