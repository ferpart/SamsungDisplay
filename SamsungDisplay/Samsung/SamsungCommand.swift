import Foundation

/// JSON-RPC envelope for Samsung Tizen `ms.remote.control` method.
///
/// Samsung's parser is strict about the exact field names, types, and value
/// strings. Do NOT rename fields, change casing, or introduce new fields:
/// the monitor will silently drop frames that don't match.
///
/// Reference: phase 01 RESEARCH.md → "Code Examples > Send a Key Command".
struct SamsungCommand: Codable, Sendable {

    /// Always `"ms.remote.control"` for remote-key commands.
    let method: String

    /// The four-field params object Tizen expects.
    let params: Params

    struct Params: Codable, Sendable {
        /// Always `"Click"` for a one-shot key press.
        let Cmd: String
        /// The Samsung key constant, e.g. `"KEY_VOLUP"`.
        let DataOfCmd: String
        /// Always the string `"false"` (not a JSON boolean — Samsung wants the string).
        let Option: String
        /// Always `"SendRemoteKey"`.
        let TypeOfRemote: String
    }

    /// Samsung Tizen remote key constants. Raw values must match Samsung's
    /// `DataOfCmd` strings exactly.
    enum Key: String, Sendable {
        case volUp = "KEY_VOLUP"
        case volDown = "KEY_VOLDOWN"
        case mute = "KEY_MUTE"
        case power = "KEY_POWER"
        case source = "KEY_SOURCE"
        case hdmi1 = "KEY_HDMI1"
        case hdmi2 = "KEY_HDMI2"
        case hdmi3 = "KEY_HDMI3"
        case hdmi4 = "KEY_HDMI4"
    }

    /// Build a `Click`-typed command for a single remote key.
    init(key: Key) {
        self.method = "ms.remote.control"
        self.params = Params(
            Cmd: "Click",
            DataOfCmd: key.rawValue,
            Option: "false",
            TypeOfRemote: "SendRemoteKey"
        )
    }
}
