import SwiftUI

@main
struct ResolutionStudioApp: App {
    init() {
        // Keep ALGetGrappaToken linked and exported for Airlift's Rust dlsym lookup.
        // The zero-sized call returns immediately and does not start a Grappa session.
        _ = forceALGetGrappaToken(0, 0, 0, nil, 0, nil, nil, 0)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

@_silgen_name("ALGetGrappaToken")
private func forceALGetGrappaToken(
    _ inVersion: UInt32,
    _ inDeviceType: UInt32,
    _ inProtocolVersion: UInt32,
    _ outBuf: UnsafeMutablePointer<UInt8>?,
    _ maxLen: Int,
    _ outLen: UnsafeMutablePointer<Int>?,
    _ errBuf: UnsafeMutablePointer<CChar>?,
    _ errLen: Int
) -> Int32
