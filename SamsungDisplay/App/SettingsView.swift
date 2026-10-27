import SwiftUI

struct SettingsView: View {
    @Bindable var controller: ConnectionController
    @Bindable var permission: MediaKeyPermission
    var preferences: AppPreferences = .shared
    @State private var discovery = MonitorDiscovery()
    @State private var ipDraft = ""
    @State private var audioOutputName: String?
    @State private var audioOutputs: [String] = []
    @State private var launchAtLogin = false
    @State private var launchAtLoginError: String?

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    monitorCard
                    audioCard
                    startupCard
                    permissionsCard
                    logsCard
                }
            }
            .padding(20)
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 520, idealHeight: 700)
        .glassWindowBackground(isResizable: true)
        .onAppear(perform: load)
    }

    private var monitorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monitor").font(.headline)
            ManualIPField(draft: $ipDraft, buttonTitle: "Save and reconnect") { controller.connect(to: $0) }
            DiscoveredMonitorsView(discovery: discovery) { monitor in
                ipDraft = monitor.ip
                controller.connect(to: monitor.ip)
            }
            Divider()
            Button("Wipe token and re-pair") { controller.wipeTokenAndReconnect() }
                .buttonStyle(.glass)
            Text("Forgets the saved pairing token. The monitor then asks you to select Allow again.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Volume keys").font(.headline)
            Picker("Audio output", selection: $audioOutputName) {
                Text("Same name as a connected display").tag(String?.none)
                ForEach(audioOutputs, id: \.self) { Text($0).tag(String?.some($0)) }
            }
            .onChange(of: audioOutputName) { _, name in preferences.audioOutputName = name }
            Text("The keys control the monitor only when this output is the macOS output device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private var startupCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch at login", isOn: launchAtLoginBinding)
            if let launchAtLoginError {
                Text(launchAtLoginError).font(.caption).foregroundStyle(.red)
            }
        }
        .glassCard()
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions").font(.headline)
            PermissionsView(permission: permission)
        }
        .glassCard()
    }

    private var logsCard: some View {
        DisclosureGroup("Logs") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(controller.logEntries.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(height: 160)
        }
        .glassCard()
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enabled in
                do {
                    try LaunchAtLogin.set(enabled)
                    launchAtLoginError = nil
                } catch {
                    launchAtLoginError = "Could not change launch at login: \(error.localizedDescription)"
                }
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        )
    }

    private func load() {
        ipDraft = preferences.monitorIP ?? ""
        audioOutputName = preferences.audioOutputName
        audioOutputs = AudioOutputDevices.names()
        if let audioOutputName, !audioOutputs.contains(audioOutputName) { audioOutputs.append(audioOutputName) }
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
