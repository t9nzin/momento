import OSLog
import SwiftUI

/// Fetches a screen's layout from the server and renders it.
///
/// `localData` is merged over the server's `data` before binding, so an app can
/// take the layout from the server while keeping the content on device.
public struct ServerDrivenScreen: View {
    let screenId: String
    let params: [String: String]
    let client: SDUIClient
    let localData: [String: JSONValue]
    let onNavigate: (String, [String: String]) -> Void

    @State private var screen: Screen?
    @State private var error: Error?
    @State private var reloadToken = 0

    public init(screenId: String, params: [String: String] = [:], client: SDUIClient,
                localData: [String: JSONValue] = [:],
                onNavigate: @escaping (String, [String: String]) -> Void) {
        self.screenId = screenId
        self.params = params
        self.client = client
        self.localData = localData
        self.onNavigate = onNavigate
    }

    public var body: some View {
        Group {
            if let screen {
                ScrollView {
                    ComponentView(screen.root, scope: BindingScope(data: screen.data.merging(localData)))
                        .padding()
                }
                .navigationTitle(screen.title)
            } else if let error {
                ContentUnavailableView {
                    Label("Couldn't load layout", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Try again") { reloadToken += 1 }
                }
            } else {
                ProgressView()
            }
        }
        .task(id: reloadToken) { await load() }
        .refreshable { await load() }
        .environment(\.sduiActionHandler, handle)
    }

    private func load() async {
        do {
            screen = try await client.screen(screenId, params: params)
            error = nil
        } catch {
            self.error = error
        }
    }

    private func handle(_ action: Action) {
        switch action {
        case .navigate(let screenId, let params):
            onNavigate(screenId, params)
        case .request(let method, let path, let refresh):
            Task {
                do {
                    try await client.send(method: method, path: path)
                    if refresh { reloadToken += 1 }
                } catch {
                    Logger.sdui.error("Request \(method, privacy: .public) \(path, privacy: .public) failed: \(error)")
                }
            }
        case .unknown(let type):
            Logger.sdui.warning("Ignoring unknown action type '\(type, privacy: .public)'")
        }
    }
}
