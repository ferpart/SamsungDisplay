import SwiftUI
import AppKit

@main
struct SamsungDisplayApp: App {
    @NSApplicationDelegateAdaptor(SamsungDisplayAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("SamsungDisplay", systemImage: appDelegate.controller.state.menuBarSymbol) {
            PopoverContent(controller: appDelegate.controller)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView(controller: appDelegate.controller)
        }
        .defaultSize(width: 480, height: 420)
        .windowResizability(.contentSize)
    }
}

@MainActor
final class SamsungDisplayAppDelegate: NSObject, NSApplicationDelegate {
    let controller = ConnectionController()
    private(set) lazy var volumeKeys = VolumeKeyRouter(controller: controller)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The unit tests use this app as their host and must not reach the real monitor.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        controller.bootstrap()
        volumeKeys.start()
    }
}
