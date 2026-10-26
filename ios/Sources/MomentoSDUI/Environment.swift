import OSLog
import SwiftUI

public extension EnvironmentValues {
    /// Called with a fully resolved action when the user taps a component.
    @Entry var sduiActionHandler: @MainActor (Action) -> Void = { action in
        Logger.sdui.warning("No sduiActionHandler set; dropping \(String(describing: action), privacy: .public)")
    }

    /// Supplies images for non-HTTP URLs, e.g. `momento://memento/<id>` for
    /// photos that only exist on this device. Return nil to show a placeholder.
    @Entry var sduiLocalImageProvider: @MainActor (URL) -> Image? = { _ in nil }
}
