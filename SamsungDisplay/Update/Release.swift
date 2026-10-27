import Foundation

struct Release: Decodable, Equatable, Sendable {
    struct Asset: Decodable, Equatable, Sendable {
        let name: String
        let downloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
        }
    }

    let tag: String
    let pageURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tag = "tag_name"
        case pageURL = "html_url"
        case assets
    }

    var version: String { tag.hasPrefix("v") ? String(tag.dropFirst()) : tag }

    var downloadURL: URL {
        assets.first { $0.name.hasSuffix(".dmg") }?.downloadURL ?? pageURL
    }

    func isNewer(than currentVersion: String) -> Bool {
        let isDotted = version.range(of: #"^\d+(\.\d+)*$"#, options: .regularExpression) != nil
        return isDotted && version.compare(currentVersion, options: .numeric) == .orderedDescending
    }
}
