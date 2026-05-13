import SwiftUI
import SwiftData

@main
struct MomentoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
                .dynamicTypeSize(.medium)
        }
        .modelContainer(for: [Folder.self, Memento.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TrayEditor()
            .task {
                FolderSeed.seedIfNeeded(context: modelContext)
            }
    }
}
