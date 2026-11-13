import Foundation
import Darwin

/// Local interface discovery used by the Airlift RSD/Lockdown multi-host dialer.
/// Device reachability is determined by an actual Airlift read, never by this helper.
enum NetworkStatus {
    struct Interface {
        let name: String
        let ipv4: String
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
            result.append(Interface(name: String(cString: name), ipv4: ipv4))
        }
        return result
    }

    /// Local interface addresses used as additional RSD/Lockdown dial candidates.
    /// Wi-Fi is tried first. Loopback, tunnel and link-local addresses are excluded.
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
}
