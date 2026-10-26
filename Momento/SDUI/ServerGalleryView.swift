import MomentoSDUI
import SwiftData
import SwiftUI

/// The gallery, laid out by the server but filled with this device's mementos.
///
/// The server decides grid vs. list, spacing and copy; `items` comes from
/// SwiftData, so photos never leave the phone.
struct ServerGalleryView: View {
    @Query(sort: \Memento.createdAt, order: .reverse) private var mementos: [Memento]
    @State private var selected: Memento?

    private let client = SDUIClient(baseURL: SDUIConfig.baseURL, userId: SDUIConfig.userId)

    var body: some View {
        NavigationStack {
            ServerDrivenScreen(screenId: "gallery", client: client, localData: localData, onNavigate: navigate)
        }
        .environment(\.sduiLocalImageProvider, image(for:))
        .sheet(item: $selected) { memento in
            MementoDetailSheet(memento: memento)
        }
    }

    /// Replaces the server's sample `items` with local mementos, shaped like
    /// the server's items so the same bindings resolve.
    private var localData: [String: JSONValue] {
        [
            "count": .number(Double(mementos.count)),
            "items": .array(mementos.map(Self.item)),
        ]
    }

    private static func item(_ memento: Memento) -> JSONValue {
        .object([
            "id": .string(memento.id.uuidString),
            "title": .string(memento.name),
            "imageUrl": .string(LocalImageURL.url(for: memento).absoluteString),
            "year": .number(Double(Calendar.current.component(.year, from: memento.createdAt))),
            "favorite": .bool(false),
        ])
    }

    private func image(for url: URL) -> Image? {
        guard let id = LocalImageURL.mementoID(from: url),
              let memento = mementos.first(where: { $0.id == id }),
              let uiImage = MementoStore.image(for: memento) else { return nil }
        return Image(uiImage: uiImage)
    }

    /// Item detail on the server describes server-side sample items, so for
    /// local mementos the app shows its own detail sheet instead.
    private func navigate(to screenId: String, params: [String: String]) {
        guard screenId == "item-detail", let id = params["itemId"].flatMap(UUID.init(uuidString:)) else { return }
        selected = mementos.first { $0.id == id }
    }
}

/// `momento://memento/<uuid>` addresses a photo that lives only on this device.
enum LocalImageURL {
    static func url(for memento: Memento) -> URL {
        URL(string: "momento://memento/\(memento.id.uuidString)")!
    }

    static func mementoID(from url: URL) -> UUID? {
        guard url.scheme == "momento", url.host() == "memento" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}

private struct MementoDetailSheet: View {
    let memento: Memento

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let image = MementoStore.image(for: memento) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }
            Text(memento.name).font(.title.bold())
            Text(memento.createdAt.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .presentationDetents([.medium, .large])
    }
}
