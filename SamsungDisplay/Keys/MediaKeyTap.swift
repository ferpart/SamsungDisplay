import AppKit
import OSLog

enum TapRepair: Equatable {
    case none
    case reenable
    case recreate

    static func after(_ type: CGEventType) -> TapRepair {
        type == .tapDisabledByTimeout || type == .tapDisabledByUserInput ? .reenable : .none
    }

    static func forHealth(exists: Bool, isValid: Bool, isEnabled: Bool, isPermitted: Bool) -> TapRepair {
        guard isPermitted else { return .none }
        guard exists, isValid else { return .recreate }
        return isEnabled ? .none : .reenable
    }
}

@MainActor
final class MediaKeyTap {
    private let permission: MediaKeyPermission
    private let shouldConsume: (MediaKeyEvent) -> Bool
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var healthTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.fp.SamsungDisplay", category: "media-keys")

    init(permission: MediaKeyPermission, shouldConsume: @escaping (MediaKeyEvent) -> Bool) {
        self.permission = permission
        self.shouldConsume = shouldConsume
    }

    func start() {
        checkHealth()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHealth() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.recreateIfPermitted() }
        }
    }

    private func checkHealth() {
        permission.refresh()
        let repair = TapRepair.forHealth(
            exists: port != nil,
            isValid: port.map(CFMachPortIsValid) ?? false,
            isEnabled: port.map { CGEvent.tapIsEnabled(tap: $0) } ?? false,
            isPermitted: permission.isGranted
        )
        apply(repair)
    }

    private func recreateIfPermitted() {
        permission.refresh()
        if permission.isGranted { apply(.recreate) }
    }

    private func apply(_ repair: TapRepair) {
        switch repair {
        case .none:
            break
        case .reenable:
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            logger.info("tap re-enabled")
        case .recreate:
            recreate()
        }
    }

    private func recreate() {
        destroy()
        let mask = CGEventMask(1 << NSEvent.EventType.systemDefined.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("tap create failed")
            return
        }
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        logger.info("tap created")
    }

    private func destroy() {
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        port = nil
        source = nil
    }

    fileprivate func handle(_ type: CGEventType, _ mediaKey: MediaKeyEvent?) -> Bool {
        let repair = TapRepair.after(type)
        if repair != .none {
            apply(repair)
            return false
        }
        guard let mediaKey else { return false }
        return shouldConsume(mediaKey)
    }
}

private func mediaKeyTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<MediaKeyTap>.fromOpaque(userInfo).takeUnretainedValue()
    let mediaKey = TapRepair.after(type) == .none ? MediaKeyEvent(event) : nil
    let consumed = MainActor.assumeIsolated { tap.handle(type, mediaKey) }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
