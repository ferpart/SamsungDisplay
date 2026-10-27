import SwiftUI

struct DiscoveredMonitorsView: View {
    @Bindable var discovery: MonitorDiscovery
    let onSelect: (SamsungDeviceInfo) -> Void
    @State private var hasSearched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer(minLength: 0)
                if discovery.isSearching { ProgressView().controlSize(.small) }
                Button("Search for monitors") {
                    hasSearched = true
                    Task { await discovery.search() }
                }
                .buttonStyle(.glass)
                .disabled(discovery.isSearching)
            }
            ForEach(discovery.monitors, id: \.wifiMac) { monitor in
                Button { onSelect(monitor) } label: {
                    VStack(alignment: .leading) {
                        Text(monitor.name).font(.headline)
                        Text("\(monitor.modelName) · \(monitor.ip)").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.glass)
            }
            if hasSearched, !discovery.isSearching, discovery.monitors.isEmpty {
                Text("No monitor answered. Enter the IP address of your monitor instead.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ManualIPField: View {
    @Binding var draft: String
    let buttonTitle: String
    let onCommit: (String) -> Void

    private var trimmed: String { draft.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        HStack {
            TextField("Monitor IP", text: $draft, prompt: Text("e.g. 192.168.1.10"))
                .textFieldStyle(.roundedBorder)
                .onSubmit(commit)
            Button(buttonTitle, action: commit)
                .buttonStyle(.glassProminent)
                .disabled(trimmed.isEmpty)
        }
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        onCommit(trimmed)
    }
}
