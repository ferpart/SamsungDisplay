import Carbon.HIToolbox

enum RemoteKeyMapping {
    static func key(forKeyCode keyCode: UInt16) -> SamsungCommand.Key? {
        switch Int(keyCode) {
        case kVK_UpArrow: .up
        case kVK_DownArrow: .down
        case kVK_LeftArrow: .left
        case kVK_RightArrow: .right
        case kVK_Return, kVK_ANSI_KeypadEnter: .enter
        case kVK_Escape, kVK_Delete: .back
        default: nil
        }
    }
}
