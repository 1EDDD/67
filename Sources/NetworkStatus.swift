import Foundation
import Darwin

/// Network route inspection for the configured LocalDevVPN target.
/// This detects a route through a tunnel interface; it does not claim Airlift is connected.
enum NetworkStatus {
    static let targetHost = "10.7.0.1"

    struct Interface {
        let name: String
        let ipv4: String
        let netmask: String?
    }

    static func interfaces() -> [Interface] {
        var result: [Interface] = []
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let head = first else { return [] }
        defer { freeifaddrs(first) }

        var current: UnsafeMutablePointer<ifaddrs>? = head
        while let item = current {
            defer { current = item.pointee.ifa_next }
            guard let address = item.pointee.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET),
                  let name = item.pointee.ifa_name,
                  let ipv4 = numericHost(address) else { continue }

            let mask = item.pointee.ifa_netmask.flatMap(numericHost)
            result.append(Interface(name: String(cString: name), ipv4: ipv4, netmask: mask))
        }
        return result
    }

    static func hasVPNRoute(to deviceIP: String = targetHost) -> Bool {
        let current = interfaces()
        guard let source = routeSource(to: deviceIP),
              let interface = current.first(where: { $0.ipv4 == source }) else {
            return false
        }
        return isTunnelInterface(interface.name)
    }

    /// Candidate addresses used by Airlift's multi-host RSD/Lockdown dialer.
    /// Wi-Fi is tried first; tunnel, loopback and link-local interfaces are excluded.
    static func tunnelHostCandidates() -> [String] {
        let current = interfaces().filter {
            !isTunnelInterface($0.name)
                && !$0.ipv4.hasPrefix("127.")
                && !$0.ipv4.hasPrefix("169.254.")
        }
        return (current.filter { $0.name == "en0" } + current.filter { $0.name != "en0" })
            .map(\.ipv4)
    }

    static func isTunnelInterface(_ name: String) -> Bool {
        name.hasPrefix("utun") || name.hasPrefix("ipsec")
            || name.hasPrefix("tap") || name.hasPrefix("ppp")
    }

    private static func numericHost(_ address: UnsafeMutablePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
            return nil
        }
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
}
