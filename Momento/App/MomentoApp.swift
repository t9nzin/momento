import SwiftUI
import SwiftData

@main
struct MomentoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: Memento.self)
    }
}

struct RootView: View {
    var body: some View {
        TrayEditor()
    }
}
