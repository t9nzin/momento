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
    /// Roughly city-block zoom — a few km across.
    private let cityZoomSpan = MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)

    private var locatedStamps: [Memento] {
        allMementos.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(locatedStamps, id: \.id) { stamp in
                    if let lat = stamp.latitude, let lon = stamp.longitude {
                        Annotation(
                            stamp.name,
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            anchor: .bottom
                        ) {
                            StampMapTile(memento: stamp)
                        }
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()
            .task { await zoomToInitialRegion() }

            VStack {
                HStack {
                    closeButton
                    Spacer()
                    recenterButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 60)
                Spacer()
                if locatedStamps.isEmpty {
                    emptyHint
                        .padding(.bottom, 48)
                }
            }
        }
        .ignoresSafeArea()
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
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(Color.white.opacity(0.18))
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

    private var emptyHint: some View {
        Text("Stamps with location will appear here.")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.65))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
    }
}

/// Small image tile that represents a stamp on the map. Mirrors the
/// `map_reference.png` look: a square photo with a thin white border and a
/// subtle drop shadow, slightly rotated for a hand-placed feel.
private struct StampMapTile: View {
    let memento: Memento

    private let size: CGFloat = 52

    private var tilt: Double {
        // Deterministic per-stamp tilt so the same stamp doesn't jitter on
        // every map redraw.
        let h = abs(memento.id.uuidString.hashValue)
        return Double(h % 11) - 5      // -5° to +5°
    }

    var body: some View {
        ZStack {
            if let ui = MementoStore.image(for: memento) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: size, height: size)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 3)
        .rotationEffect(.degrees(tilt))
    }
}
