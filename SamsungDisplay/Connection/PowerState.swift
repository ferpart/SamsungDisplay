enum PowerState: Equatable, Sendable {
    case on
    case standby
    case off

    init(apiValue: String?) {
        switch apiValue?.lowercased() {
        case "standby": self = .standby
        case "off": self = .off
        default: self = .on
        }
    }

    var label: String {
        switch self {
        case .on: "On"
        case .standby: "Standby"
        case .off: "Off"
        }
    }
}
