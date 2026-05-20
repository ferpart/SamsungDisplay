import SwiftUI

/// Settings window content. Phase 2 minimal set; Phase 3 will extend.
///
/// Contents:
///   * Monitor IP text field — bound to a local @State string mirrored to
///     AppPreferences.shared.monitorIP on submit/blur. On a non-empty commit,
///     controller.start(ip:) is called so the new IP takes effect immediately.
///   * Wipe Token and Re-pair button — same code path as the popover's
///     sticky-deny recovery (`controller.wipeTokenAndReconnect()`).
///   * Logs — scrollable list of controller.logEntries, auto-scrolls to the
///     newest line via ScrollViewReader.
struct SettingsView: View {
    @Bindable var controller: ConnectionController
    @State private var ipDraft: String = ""

    var body: some View {
        Form {
            Section("Monitor") {
                TextField("Monitor IP", text: $ipDraft, prompt: Text("e.g. 192.168.1.10"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitIP() }
                Button("Save and reconnect") { commitIP() }
                    .buttonStyle(.borderedProminent)
                    .disabled(ipDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("Pairing") {
                Button("Wipe token and re-pair") {
                    controller.wipeTokenAndReconnect()
                }
                Text("Forgets the saved Samsung pairing token and re-triggers the pairing popup on your TV.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Logs") {
                logs
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 360)
        .onAppear { ipDraft = AppPreferences.shared.monitorIP ?? "" }
    }

    private var logs: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(controller.logEntries.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(idx)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 160, maxHeight: 240)
            .onChange(of: controller.logEntries.count) { _, newCount in
                guard newCount > 0 else { return }
                withAnimation { proxy.scrollTo(newCount - 1, anchor: .bottom) }
            }
        }
    }

    private func commitIP() {
        let trimmed = ipDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        AppPreferences.shared.monitorIP = trimmed
        controller.start(ip: trimmed)
    }
}
