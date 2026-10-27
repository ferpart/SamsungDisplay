import Foundation

extension Error {
    // NSError userInfo can hold the failing URL, and that URL includes the token.
    var redactedDescription: String {
        let error = self as NSError
        return error.userInfo.isEmpty ? String(describing: self) : "\(error.domain) \(error.code)"
    }
}
