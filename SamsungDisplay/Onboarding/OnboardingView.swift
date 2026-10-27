import SwiftUI

struct OnboardingView: View {
    @Bindable var controller: ConnectionController
    @Bindable var permission: MediaKeyPermission
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var discovery = MonitorDiscovery()
    @State private var ipDraft = ""
    @State private var storedIP: String?
    @State private var keysSkipped = false

    init(controller: ConnectionController, permission: MediaKeyPermission, preferences: AppPreferences = .shared) {
        self.controller = controller
        self.permission = permission
        _storedIP = State(initialValue: preferences.monitorIP)
    }

    private var step: OnboardingStep {
        OnboardingStep.current(
            storedIP: storedIP,
            state: controller.state,
            keysGranted: permission.isGranted,
            keysSkipped: keysSkipped
        )
    }

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    Text("Set up SamsungDisplay")
                } icon: {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 40, height: 40)
                }
                .font(.title2.bold())
                content.glassCard()
            }
        }
        .padding(24)
        .frame(width: 460)
        .glassWindowBackground()
        .onAppear { NSApp.activate() }
        .task {
            while !Task.isCancelled {
                permission.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .findMonitor: findMonitor
        case .pairing: pairing
        case .denied: denied
        case .keys: keys
        case .done: done
        }
    }

    private var findMonitor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step 1 of 3 · Find your monitor").font(.headline)
            Text("The app talks to your monitor over your home network. When you search, macOS asks for Local Network access. Select Allow.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DiscoveredMonitorsView(discovery: discovery) { connect(to: $0.ip) }
            Divider()
            Text("Or enter the IP address of your monitor. Find it on the monitor in Settings → General → Network.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ManualIPField(draft: $ipDraft, buttonTitle: "Connect", onCommit: connect(to:))
        }
    }

    private var pairing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step 2 of 3 · Pair with your monitor").font(.headline)
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Look at your monitor. Select Allow when it asks about SamsungDisplay.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Use a different IP address") { changeMonitor() }
                .buttonStyle(.glass)
        }
    }

    private var denied: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step 2 of 3 · The monitor said no").font(.headline)
            Text("The monitor remembers the answer. On the monitor, open Settings → All Settings → Connections → Device Connect Manager → Device List → SamsungDisplay → Allow.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("I selected Allow. Try again") { controller.wipeTokenAndReconnect() }
                    .buttonStyle(.glassProminent)
                Button("Use a different IP address") { changeMonitor() }
                    .buttonStyle(.glass)
            }
        }
    }

    private var keys: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step 3 of 3 · Volume keys").font(.headline)
            Text("The monitor is paired. To use the volume keys of your keyboard, macOS must allow the app to read them.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            PermissionsView(permission: permission, includeLocalNetwork: false)
            Button("Skip for now") { keysSkipped = true }
                .buttonStyle(.glass)
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("All set", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text("Use the monitor icon in the menu bar to control your monitor.")
                .font(.callout)
            Button("Finish") { dismissWindow(id: "onboarding") }
                .buttonStyle(.glassProminent)
        }
    }

    private func connect(to ip: String) {
        storedIP = ip
        controller.connect(to: ip)
    }

    private func changeMonitor() {
        controller.forgetMonitor()
        storedIP = nil
    }
}
