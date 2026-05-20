import SwiftUI
import AppKit

@main
struct SamsungDisplayApp: App {
    @NSApplicationDelegateAdaptor(SamsungDisplayAppDelegate.self) private var appDelegate
    @State private var controller = ConnectionController()

    var body: some Scene {
        MenuBarExtra("SamsungDisplay", systemImage: controller.state.menuBarSymbol) {
            PopoverContent(controller: controller)
                .onAppear {
                    appDelegate.controllerRef = controller
                    controller.bootstrap()
                }
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView(controller: controller)
                .onAppear {
                    appDelegate.controllerRef = controller
                }
        }
        .defaultSize(width: 480, height: 420)
        .windowResizability(.contentSize)
    }
}

/// AppDelegate adapter for SwiftUI's `@NSApplicationDelegateAdaptor`.
///
/// SwiftUI's `App` lifecycle does not expose a clean launch hook for a
/// menu-bar-only (`LSUIElement=true`) app — the only scene we render up-front
/// is the `MenuBarExtra` icon, and its content view is materialized lazily
/// on first click. The popover's `.onAppear` therefore handles the eager
/// bootstrap in the common case.
///
/// This adapter exists primarily to:
///   1. Receive a reference to the SwiftUI-owned `ConnectionController` once
///      the scene's `@State` is ready (`controllerRef`), so future launch-time
///      hooks (Phase 3: launch-at-login + permission prompts) can reach it.
///   2. Suppress any default SwiftUI window creation behavior associated with
///      the missing main-window scene (we use a `MenuBarExtra` instead).
///
/// Phase 3 will replace this stub with the real launch-flow controller.
@MainActor
final class SamsungDisplayAppDelegate: NSObject, NSApplicationDelegate {
    /// Weak slot filled by the SwiftUI scene on first appearance. The AppDelegate
    /// cannot construct the controller itself (different lifecycle), so the
    /// scene injects it.
    weak var controllerRef: ConnectionController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // No-op for Phase 2. The popover's `.onAppear` calls
        // `controller.bootstrap()` on the first menu bar click, which is
        // sufficient for the Wave 2 contract. Phase 3 will add a real
        // launch-at-login / pre-popover bootstrap here.
    }
}
