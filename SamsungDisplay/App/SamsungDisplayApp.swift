import SwiftUI

@main
struct SamsungDisplayApp: App {
    var body: some Scene {
        WindowGroup("SamsungDisplay — Phase 1 Validation Harness") {
            ValidationHarnessView()
                .frame(minWidth: 500, minHeight: 400)
        }
    }
}
