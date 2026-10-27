import SwiftUI
import AppKit

@main
struct SamsungDisplayApp: App {
    @NSApplicationDelegateAdaptor(SamsungDisplayAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("SamsungDisplay", image: appDelegate.controller.state.menuBarImage(animationStep: appDelegate.menuBarAnimator.step)) {
            PopoverContent(controller: appDelegate.controller)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView(controller: appDelegate.controller, permission: appDelegate.volumeKeys.permission)
        }
        .windowResizability(.contentMinSize)

        Window("Remote", id: "remote") {
            RemoteView(controller: appDelegate.controller)
        }
        .windowResizability(.contentSize)

        Window("Set up SamsungDisplay", id: "onboarding") {
            OnboardingView(controller: appDelegate.controller, permission: appDelegate.volumeKeys.permission)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(AppLaunch.needsOnboarding ? .presented : .suppressed)
    }
}

enum AppLaunch {
    static var isRunningTests: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }

    static var needsOnboarding: Bool {
        !isRunningTests && (AppPreferences.shared.monitorIP ?? "").isEmpty
    }
}

@MainActor
final class SamsungDisplayAppDelegate: NSObject, NSApplicationDelegate {
    let controller = ConnectionController()
    let menuBarAnimator = MenuBarAnimator()
    private(set) lazy var volumeKeys = VolumeKeyRouter(controller: controller)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = AppPreferences.shared.appearance.nsAppearance
        // The unit tests use this app as their host and must not reach the real monitor.
        guard !AppLaunch.isRunningTests else { return }
        animateMenuBarWhileConnecting()
        controller.bootstrap()
        volumeKeys.start()
    }

    private func animateMenuBarWhileConnecting() {
        withObservationTracking {
            menuBarAnimator.update(isConnecting: controller.state == .connecting)
        } onChange: {
            Task { @MainActor [weak self] in self?.animateMenuBarWhileConnecting() }
        }
    }
}
