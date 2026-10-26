import AppKit
import SwiftUI

struct PermissionsView: View {
    @Bindable var permission: MediaKeyPermission
    var includeLocalNetwork = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if includeLocalNetwork {
                PermissionRow(
                    title: "Local Network",
                    detail: "The app talks to your monitor over your home network. macOS asks once, the first time the app looks for a monitor. macOS does not show this state to apps.",
                    granted: nil,
                    pane: "Privacy_LocalNetwork"
                )
            }
            PermissionRow(
                title: "Input Monitoring",
                detail: "The app reads the volume and mute keys of your keyboard. It does not read any other key. Allow Input Monitoring or Accessibility.",
                granted: permission.isInputMonitoringGranted,
                pane: "Privacy_ListenEvent"
            )
            PermissionRow(
                title: "Accessibility",
                detail: "macOS accepts Accessibility as an alternative to Input Monitoring.",
                granted: permission.isAccessibilityGranted,
                pane: "Privacy_Accessibility"
            )
            if !permission.isGranted {
                Button("Allow volume keys…") { permission.request() }
                    .buttonStyle(.glassProminent)
            }
        }
        .task {
            while !Task.isCancelled {
                permission.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool?
    let pane: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let granted {
                    Label(granted ? "Allowed" : "Not allowed",
                          systemImage: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(granted ? Color.green : Color.red)
                        .font(.subheadline)
                }
            }
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
    }
}
