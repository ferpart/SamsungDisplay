import Darwin
import Foundation

enum WakeOnLANError: Error, Sendable {
    case invalidMAC
    case socketFailed(errno: Int32)
}

enum WakeOnLAN {
    static func magicPacket(mac: String) -> Data? {
        let octets = mac.split(whereSeparator: { $0 == ":" || $0 == "-" }).compactMap { UInt8($0, radix: 16) }
        guard octets.count == 6 else { return nil }
        return Data(repeating: 0xFF, count: 6) + Data((0..<16).flatMap { _ in octets })
    }

    // Network.framework cannot send to a broadcast address, so this uses a BSD socket.
    static func send(mac: String, port: UInt16 = 9) throws {
        guard let packet = magicPacket(mac: mac) else { throw WakeOnLANError.invalidMAC }

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw WakeOnLANError.socketFailed(errno: errno) }
        defer { close(fd) }

        var enabled: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &enabled, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = INADDR_BROADCAST

        let sent = packet.withUnsafeBytes { buffer in
            withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, buffer.baseAddress, buffer.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == packet.count else { throw WakeOnLANError.socketFailed(errno: errno) }
    }
}
