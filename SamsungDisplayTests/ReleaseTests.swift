import XCTest
@testable import SamsungDisplay

final class ReleaseTests: XCTestCase {
    private func release(tag: String) -> Release {
        Release(tag: tag, pageURL: URL(string: "https://example.com/page")!, assets: [])
    }

    func test_newerTag_isNewer() {
        XCTAssertTrue(release(tag: "v1.0.3").isNewer(than: "1.0.2"))
    }

    func test_sameTag_isNotNewer() {
        XCTAssertFalse(release(tag: "v1.0.3").isNewer(than: "1.0.3"))
    }

    func test_olderTag_isNotNewer() {
        XCTAssertFalse(release(tag: "v1.0.1").isNewer(than: "1.0.3"))
    }

    func test_tagWithoutPrefix_isCompared() {
        XCTAssertTrue(release(tag: "2.0").isNewer(than: "1.9"))
    }

    func test_numericCompare_ranksTenAboveNine() {
        XCTAssertTrue(release(tag: "v1.0.10").isNewer(than: "1.0.9"))
        XCTAssertFalse(release(tag: "v1.0.9").isNewer(than: "1.0.10"))
    }

    func test_badTag_isNotNewer() {
        XCTAssertFalse(release(tag: "nightly").isNewer(than: "1.0"))
        XCTAssertFalse(release(tag: "").isNewer(than: "1.0"))
        XCTAssertFalse(release(tag: "v1.0-beta").isNewer(than: "0.9"))
    }

    private let fixture = """
    {
      "tag_name": "v1.0.3",
      "html_url": "https://github.com/ferpart/SamsungDisplay/releases/tag/v1.0.3",
      "name": "1.0.3",
      "assets": [
        {"name": "checksums.txt", "browser_download_url": "https://github.com/ferpart/SamsungDisplay/releases/download/v1.0.3/checksums.txt"},
        {"name": "SamsungDisplay-1.0.3.dmg", "browser_download_url": "https://github.com/ferpart/SamsungDisplay/releases/download/v1.0.3/SamsungDisplay-1.0.3.dmg"}
      ]
    }
    """

    func test_decode_readsTagPageAndAssets() throws {
        let release = try JSONDecoder().decode(Release.self, from: Data(fixture.utf8))
        XCTAssertEqual(release.tag, "v1.0.3")
        XCTAssertEqual(release.version, "1.0.3")
        XCTAssertEqual(release.pageURL.absoluteString, "https://github.com/ferpart/SamsungDisplay/releases/tag/v1.0.3")
        XCTAssertEqual(release.assets.count, 2)
    }

    func test_downloadURL_prefersDMGAsset() throws {
        let release = try JSONDecoder().decode(Release.self, from: Data(fixture.utf8))
        XCTAssertEqual(release.downloadURL.lastPathComponent, "SamsungDisplay-1.0.3.dmg")
    }

    func test_downloadURL_fallsBackToPageWithoutDMG() {
        let release = release(tag: "v1.0.3")
        XCTAssertEqual(release.downloadURL, release.pageURL)
    }
}
