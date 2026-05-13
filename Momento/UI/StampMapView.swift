import SwiftUI
import SwiftData
import MapKit
import UIKit

struct StampMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allMementos: [Memento]

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var didInitialZoom = false
    @State private var visibleLatitudeDelta: CLLocationDegrees = 0.04
    @State private var groupDisplayIndices: [String: Int] = [:]
    /// Roughly city-block zoom — a few km across.
    private let cityZoomSpan = MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
    private let stampGroupingDistanceMeters: CLLocationDistance = 180

    private var locatedStamps: [Memento] {
        allMementos.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var stampGroups: [MapStampGroup] {
        clusteredStampGroups(from: locatedStamps)
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var stampZoomScale: CGFloat {
        let raw = log2(cityZoomSpan.latitudeDelta / max(visibleLatitudeDelta, 0.0001))
        return min(max(1.0 + CGFloat(raw) * 0.055, 0.84), 1.12)
    }

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(stampGroups) { group in
                    Annotation(
                        "",
                        coordinate: group.coordinate,
                        anchor: .center
                    ) {
                        StampMapTile(
                            memento: displayedStamp(for: group),
                            count: group.count,
                            zoomScale: stampZoomScale
                        )
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 12)
                                .onEnded { value in
                                    cycleStamp(in: group, translation: value.translation.width)
                                }
                        )
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()
            .onMapCameraChange(frequency: .continuous) { context in
                visibleLatitudeDelta = context.region.span.latitudeDelta
            }
            .task { await zoomToInitialRegion() }

            mapEdgeBlur

            VStack {
                HStack {
                    closeButton
                    Spacer()
                    recenterButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 60)
                Spacer()
            }
        }
        .ignoresSafeArea()
    }

    private var mapEdgeBlur: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 150)
                .mask(
                    LinearGradient(
                        colors: [.black.opacity(0.70), .black.opacity(0.18), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Spacer(minLength: 0)

            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 170)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.16), .black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var closeButton: some View {
        glassCircleButton(systemName: "chevron.left") { dismiss() }
    }

    private var recenterButton: some View {
        glassCircleButton(systemName: "location.fill") { recenterOnUser() }
    }

    private func glassCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
    }

    // MARK: - Camera helpers

    /// Wait briefly for a location fix, then zoom to a city-level region
    /// around it. Falls back to the bounding box of located stamps if no fix
    /// is available.
    private func zoomToInitialRegion() async {
        guard !didInitialZoom else { return }
        LocationProvider.shared.start()

        // Poll up to ~3s for a fresh fix without holding the view.
        for _ in 0..<15 {
            if let coord = LocationProvider.shared.currentCoordinate(maxAge: 600) {
                applyRegion(center: coord, span: cityZoomSpan, animated: false)
                didInitialZoom = true
                return
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        // No fix — fall back to a region covering existing located stamps.
        if let fallback = stampsBoundingRegion() {
            applyRegion(center: fallback.center, span: fallback.span, animated: false)
            didInitialZoom = true
        }
    }

    private func recenterOnUser() {
        if let coord = LocationProvider.shared.currentCoordinate(maxAge: 600) {
            applyRegion(center: coord, span: cityZoomSpan, animated: true)
        } else {
            // No fix yet; ask the system for the user-location-tracking camera
            // which will hop to the dot as soon as it arrives.
            withAnimation(.easeInOut(duration: 0.4)) {
                cameraPosition = .userLocation(fallback: .automatic)
            }
        }
    }

    private func applyRegion(center: CLLocationCoordinate2D,
                             span: MKCoordinateSpan,
                             animated: Bool) {
        let region = MKCoordinateRegion(center: center, span: span)
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func stampsBoundingRegion() -> MKCoordinateRegion? {
        let coords = locatedStamps.compactMap { stamp -> CLLocationCoordinate2D? in
            guard let lat = stamp.latitude, let lon = stamp.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else { return nil }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, cityZoomSpan.latitudeDelta),
            longitudeDelta: max((maxLon - minLon) * 1.6, cityZoomSpan.longitudeDelta)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private func clusteredStampGroups(from stamps: [Memento]) -> [MapStampGroup] {
        var groups: [[Memento]] = []

        for stamp in stamps.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard let coordinate = stamp.coordinate else { continue }
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let idx = groups.firstIndex(where: { group in
                guard let center = averageCoordinate(for: group) else { return false }
                let groupLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                return location.distance(from: groupLocation) <= stampGroupingDistanceMeters
            }) {
                groups[idx].append(stamp)
            } else {
                groups.append([stamp])
            }
        }

        return groups.enumerated().map { idx, stamps in
            MapStampGroup(key: "group-\(idx)-\(stamps.map(\.id.uuidString).joined(separator: "-"))",
                          stamps: stamps)
        }
    }

    private func averageCoordinate(for stamps: [Memento]) -> CLLocationCoordinate2D? {
        let coords = stamps.compactMap(\.coordinate)
        guard !coords.isEmpty else { return nil }
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func displayedStamp(for group: MapStampGroup) -> Memento {
        let stamps = group.orderedStamps
        guard !stamps.isEmpty else { return group.primaryStamp }
        let idx = groupDisplayIndices[group.id] ?? 0
        return stamps[wrappedIndex(idx, count: stamps.count)]
    }

    private func cycleStamp(in group: MapStampGroup, translation: CGFloat) {
        guard group.count > 1, abs(translation) > 18 else { return }
        let direction = translation < 0 ? 1 : -1
        let current = groupDisplayIndices[group.id] ?? 0
        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
            groupDisplayIndices[group.id] = wrappedIndex(current + direction, count: group.count)
        }
    }

    private func wrappedIndex(_ index: Int, count: Int) -> Int {
        let remainder = index % count
        return remainder >= 0 ? remainder : remainder + count
    }
}

private struct MapStampGroup: Identifiable {
    let key: String
    let stamps: [Memento]

    var id: String { key }
    var count: Int { stamps.count }
    var orderedStamps: [Memento] {
        stamps.sorted { $0.createdAt > $1.createdAt }
    }
    var primaryStamp: Memento {
        orderedStamps.first ?? stamps[0]
    }
    var createdAt: Date { primaryStamp.createdAt }

    var coordinate: CLLocationCoordinate2D {
        let coords = stamps.compactMap { stamp -> CLLocationCoordinate2D? in
            guard let lat = stamp.latitude, let lon = stamp.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        guard !coords.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lon = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

private extension Memento {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Small image tile that represents a stamp on the map. It reuses the same
/// perforated postage shape as the cutter review, with a soft lifted shadow.
private struct StampMapTile: View {
    let memento: Memento
    let count: Int
    let zoomScale: CGFloat

    private var hashSeed: UInt {
        memento.id.uuidString.hashValue.magnitude
    }

    private var width: CGFloat {
        CGFloat(44 + Int(hashSeed % 3) * 4) * zoomScale
    }

    private var height: CGFloat {
        width / StampVisualMetrics.aspectRatio
    }

    private var tilt: Double {
        // Deterministic per-stamp tilt so the same stamp doesn't jitter on
        // every map redraw.
        Double(Int(hashSeed % 9)) - 4      // -4° to +4°
    }

    var body: some View {
        let shape = PostageStampShape(bite: 4.2, spacing: 10.5)

        ZStack(alignment: .topTrailing) {
            stampLayer(shape: shape)
                .rotationEffect(.degrees(tilt))
                .zIndex(0)

            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 14 * zoomScale, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 25 * zoomScale, height: 25 * zoomScale)
                    .background(Circle().fill(Color(red: 0.18, green: 0.55, blue: 1.0)))
                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                    .offset(x: 16 * zoomScale, y: -16 * zoomScale)
                    .zIndex(10)
            }
        }
        .frame(width: width + 34 * zoomScale, height: height + 34 * zoomScale)
    }

    private func stampLayer(shape: PostageStampShape) -> some View {
        ZStack {
            ZStack {
                if let ui = MementoStore.image(for: memento) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: width, height: height)
                }
            }
            .clipShape(shape)
            .background(
                shape
                    .fill(Color.black.opacity(0.12))
                    .scaleEffect(1.035)
                    .shadow(color: .black.opacity(0.24), radius: 7, x: 0, y: 5)
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.10),
                        Color.clear,
                        Color.black.opacity(0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(shape)
                .allowsHitTesting(false)
            )
        }
    }
}
