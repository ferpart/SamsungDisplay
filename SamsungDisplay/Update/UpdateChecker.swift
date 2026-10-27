import Foundation
import Observation

@MainActor
@Observable
final class UpdateChecker {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case failed
    }

    nonisolated static let latestReleaseURL = URL(string: "https://api.github.com/repos/ferpart/SamsungDisplay/releases/latest")!
    static let automaticInterval: Duration = .seconds(24 * 60 * 60)

    private(set) var status = Status.idle
    private let preferences: AppPreferences
    private let currentVersion: String
    private let fetchLatest: @Sendable () async throws -> Release
    private var automaticTask: Task<Void, Never>?

    init(
        preferences: AppPreferences = .shared,
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
        fetchLatest: @escaping @Sendable () async throws -> Release = UpdateChecker.fetchLatestRelease
    ) {
        self.preferences = preferences
        self.currentVersion = currentVersion
        self.fetchLatest = fetchLatest
    }

    var availableRelease: Release? {
        if case .available(let release) = status { release } else { nil }
    }

    func check(isAutomatic: Bool = false) async {
        if status == .checking { return }
        let previous = status
        status = .checking
        do {
            let release = try await fetchLatest()
            status = release.isNewer(than: currentVersion) ? .available(release) : .upToDate
        } catch {
            status = isAutomatic ? previous : .failed
        }
    }

    func startAutomaticChecks() {
        guard automaticTask == nil else { return }
        automaticTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if preferences.automaticUpdateChecks { await check(isAutomatic: true) }
                try? await Task.sleep(for: Self.automaticInterval)
            }
        }
    }

    nonisolated static func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Release.self, from: data)
    }
}
