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
    @State private var appearance = AppearanceMode.automatic
    @State private var launchAtLoginError: String?
    @State private var ipRejected = false

    var body: some View {
        Form {
            monitorSection
            volumeKeysSection
            generalSection
            Section("Permissions") {
                PermissionsView(permission: permission)
            }
            logsSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(minWidth: 480, idealWidth: 520, minHeight: 520, idealHeight: 700)
        .glassWindowBackground(isResizable: true)
        .onAppear(perform: load)
    }

    private var monitorSection: some View {
        Section {
            ManualIPField(draft: $ipDraft, buttonTitle: "Save and reconnect") { ipRejected = !controller.connect(to: $0) }
            if ipRejected {
                Text("Enter an IPv4 address, for example 192.168.1.10.").font(.caption).foregroundStyle(.red)
            }
            DiscoveredMonitorsView(discovery: discovery) { monitor in
                ipDraft = monitor.ip
                controller.connect(to: monitor.ip)
            }
            LabeledContent("Pairing") {
                Button("Wipe token and re-pair") { controller.wipeTokenAndReconnect() }
            }
        } header: {
            Text("Monitor")
        } footer: {
            Text("Wipe the token to forget the pairing. The monitor then asks you to select Allow again.")
                .foregroundStyle(.secondary)
        }
    }

    private var volumeKeysSection: some View {
        Section {
            Picker("Audio output", selection: $audioOutputName) {
                Text("Same name as a connected display").tag(String?.none)
                ForEach(audioOutputs, id: \.self) { Text($0).tag(String?.some($0)) }
            }
            .onChange(of: audioOutputName) { _, name in preferences.audioOutputName = name }
        } header: {
            Text("Volume keys")
        } footer: {
            Text("The keys control the monitor only when this output is the macOS output device.")
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        Section("General") {
            LabeledContent("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearanceMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .onChange(of: appearance) { _, mode in
                preferences.appearance = mode
                NSApp.appearance = mode.nsAppearance
            }
            Toggle("Launch at login", isOn: launchAtLoginBinding)
                .toggleStyle(.switch)
            if let launchAtLoginError {
                Text(launchAtLoginError).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private var logsSection: some View {
        Section {
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
        }
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
        appearance = preferences.appearance
    }
}
