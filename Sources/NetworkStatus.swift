import Foundation
import Darwin

/// Checks the route selected by iOS for the Airlift loopback host.
/// A saved preference is never treated as proof that LocalDevVPN is connected.
enum NetworkStatus {
    private static let targetHost = "10.7.0.1"

    static func localDevVPNIsConnected() -> Bool {
        guard let sourceAddress = routeSource(to: targetHost) else { return false }
        guard let interfaceName = ipv4Interfaces().first(where: { $0.address == sourceAddress })?.name else {
            return false
        }
        return isTunnelInterface(interfaceName)
    }

    private struct IPv4Interface {
        let name: String
        let address: String
    }

    private static func ipv4Interfaces() -> [IPv4Interface] {
        var results: [IPv4Interface] = []
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let head = first else { return [] }
        defer { freeifaddrs(first) }

        var current: UnsafeMutablePointer<ifaddrs>? = head
        while let item = current {
            defer { current = item.pointee.ifa_next }
            guard let address = item.pointee.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET),
                  let rawName = item.pointee.ifa_name,
                  let numeric = numericHost(address) else { continue }
            results.append(IPv4Interface(name: String(cString: rawName), address: numeric))
        }
        return results
    }

    private static func numericHost(_ address: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
        guard result == 0 else { return nil }
        return String(cString: host)
    }

    private static func routeSource(to host: String) -> String? {
        var remote = sockaddr_in()
        remote.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        remote.sin_family = sa_family_t(AF_INET)
        remote.sin_port = in_port_t(9).bigEndian

        guard host.withCString({ inet_pton(AF_INET, $0, &remote.sin_addr) }) == 1 else {
            return nil
        }

        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else { return nil }
        defer { close(socketFD) }

        let connected = withUnsafePointer(to: remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { return nil }

        var local = sockaddr_in()
        var localLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socketFD, $0, &localLength)
            }
        }
        guard named == 0, local.sin_addr.s_addr != 0 else { return nil }

        return withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1, numericHost)
        }
    }

    private static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }
}
