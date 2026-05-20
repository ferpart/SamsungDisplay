import SwiftUI

/// Phase 1 hardware-validation harness.
///
/// One-window SwiftUI view that exercises every Wave 1 building block end-to-end
/// against a real Samsung Odyssey OLED G95SC:
///
/// * `AppPreferences.shared.monitorIP` — round-trip the user-entered IP through
///   UserDefaults (proves CONN-02 is not hardcoded).
/// * `TokenStore.shared` — save/load/delete the pairing token in macOS Keychain
///   (proves CONN-04 token persistence across app restart).
/// * `SamsungWSActor` — open `wss://<ip>:8002`, perform pairing if no token,
///   send `KEY_VOLUP/KEY_VOLDOWN/KEY_MUTE`, disconnect (proves CONN-01).
/// * `SamsungTLSDelegate` — scoped TLS bypass exercised on the only host the
///   user configured, no global ATS holes (proves CONN-07).
///
/// Phase 2 replaces this harness with the real menu-bar UX. The harness's job
/// is only to expose every interaction the real app will need to perform, in a
/// form that a human can drive while watching the monitor.
struct ValidationHarnessView: View {

    // MARK: - State

    @State private var ip: String = ""
    @State private var log: [String] = []
    @State private var isWorking: Bool = false
    @State private var wsActor: SamsungWSActor = SamsungWSActor()

    private static let logCap = 50

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SamsungDisplay — Phase 1 Validation Harness")
                .font(.headline)

            HStack {
                Text("Monitor IP:")
                TextField("192.168.1.42", text: $ip, onCommit: persistIP)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 160)
                    .disableAutocorrection(true)
            }

            HStack(spacing: 8) {
                Button("Connect") { connect() }
                    .disabled(ip.isEmpty || isWorking)
                Button("Disconnect") { disconnect() }
                    .disabled(isWorking)
                Spacer()
                Button("Wipe Token") { wipeToken() }
                    .disabled(isWorking)
            }

            HStack(spacing: 8) {
                Button("Send KEY_VOLUP") { send(.volUp) }
                Button("Send KEY_VOLDOWN") { send(.volDown) }
                Button("Send KEY_MUTE") { send(.mute) }
            }
            .disabled(isWorking)

            Divider()

            Text("Log (most recent at bottom)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(log.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .id(idx)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)
                .onChange(of: log.count) { _, _ in
                    if let last = log.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(16)
        .onAppear {
            ip = AppPreferences.shared.monitorIP ?? ""
            append("ready. saved IP: \(ip.isEmpty ? "<none>" : ip)")
            if TokenStore.shared.load() != nil {
                append("saved token present in Keychain")
            } else {
                append("no saved token")
            }
        }
    }

    // MARK: - Actions

    private func persistIP() {
        AppPreferences.shared.monitorIP = ip.isEmpty ? nil : ip
    }

    private func connect() {
        persistIP()
        let target = ip
        let savedToken = TokenStore.shared.load()
        append("connecting to \(target) (token: \(savedToken == nil ? "none" : "present"))")
        isWorking = true
        Task {
            do {
                let token = try await wsActor.connect(to: target, token: savedToken)
                if token != savedToken {
                    try TokenStore.shared.save(token)
                    await MainActor.run {
                        append("paired — token saved to Keychain")
                    }
                } else {
                    await MainActor.run {
                        append("reconnected with saved token (no re-pair)")
                    }
                }
            } catch {
                await MainActor.run {
                    append("connect failed: \(String(describing: error))")
                }
            }
            await MainActor.run { isWorking = false }
        }
    }

    private func send(_ key: SamsungCommand.Key) {
        Task {
            do {
                try await wsActor.sendKey(key)
                await MainActor.run {
                    append("sent \(key.rawValue)")
                }
            } catch {
                await MainActor.run {
                    append("send \(key.rawValue) failed: \(String(describing: error))")
                }
            }
        }
    }

    private func disconnect() {
        Task {
            await wsActor.disconnect()
            await MainActor.run {
                append("disconnected")
            }
        }
    }

    private func wipeToken() {
        TokenStore.shared.delete()
        append("token wiped from Keychain")
    }

    // MARK: - Log helpers

    private func append(_ line: String) {
        let stamp = Self.timestamp()
        log.append("\(stamp)  \(line)")
        if log.count > Self.logCap {
            log.removeFirst(log.count - Self.logCap)
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}
