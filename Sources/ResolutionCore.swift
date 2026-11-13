import Foundation
import Darwin

// MARK: - Resolution model and presets

struct CanvasResolution: Equatable {
    let width: Int
    let height: Int

    var orientationLabel: String { width >= height ? "Landscape" : "Portrait" }
    var megapixels: String { String(format: "%.2f MP", Double(width * height) / 1_000_000) }
    var displayValue: String { "\(width) × \(height)" }
}

struct ResolutionPreset: Identifiable {
    let id: String
    let name: String
    let resolution: CanvasResolution

    static let all = [
        ResolutionPreset(id: "pro11-m2", name: "iPad Pro 11 M2", resolution: .init(width: 2388, height: 1668)),
        ResolutionPreset(id: "mini5", name: "iPad mini 5", resolution: .init(width: 2048, height: 1536)),
        ResolutionPreset(id: "ipad8", name: "iPad 8", resolution: .init(width: 2160, height: 1620)),
        ResolutionPreset(id: "fullhd", name: "Full HD", resolution: .init(width: 1920, height: 1080))
    ]
}

enum ResolutionEditorError: LocalizedError {
    case invalidNumber, outOfRange, invalidPropertyList, verificationFailed

    var errorDescription: String? {
        switch self {
        case .invalidNumber: return "Enter whole numbers for width and height."
        case .outOfRange: return "Dimensions must be between 320 and 6000 pixels, with at most 25 million pixels total."
        case .invalidPropertyList: return "The display configuration is not a valid property list."
        case .verificationFailed: return "The device did not report the requested canvas values after writing."
        }
    }
}

// MARK: - Pairing file

enum PairingStore {
    private static let fileName = "airlift_pairing.plist"
    private static let defaultsKey = "airliftPairingPath"

    static var currentURL: URL? {
        if let stored = UserDefaults.standard.string(forKey: defaultsKey) {
            let url = URL(fileURLWithPath: stored)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let fallback = supportDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    static var currentFileName: String { currentURL?.lastPathComponent ?? "No pairing file imported" }

    @discardableResult
    static func importFile(from sourceURL: URL) throws -> URL {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: sourceURL)
        guard !data.isEmpty else { throw PairingStoreError.emptyFile }
        let root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard root is [String: Any] else { throw PairingStoreError.invalidPairingRecord }

        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let destination = supportDirectory.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)
        UserDefaults.standard.set(destination.path, forKey: defaultsKey)
        return destination
    }

    private static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("67", isDirectory: true)
    }
}

enum PairingStoreError: LocalizedError {
    case emptyFile, invalidPairingRecord

    var errorDescription: String? {
        switch self {
        case .emptyFile: return "The selected pairing file is empty."
        case .invalidPairingRecord: return "The selected file is not a valid property-list pairing record."
        }
    }
}

// MARK: - Local backups

enum BackupStore {
    private static let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("67/ResolutionBackups", isDirectory: true)
    private static let latestName = "latest-original.plist"

    static var latestURL: URL { folder.appendingPathComponent(latestName) }
    static var hasBackup: Bool { FileManager.default.fileExists(atPath: latestURL.path) }

    static func save(_ data: Data) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        try data.write(
            to: folder.appendingPathComponent("original-\(formatter.string(from: Date())).plist"),
            options: .atomic
        )
        try data.write(to: latestURL, options: .atomic)
    }

    static func loadLatest() throws -> Data {
        guard hasBackup else { throw BackupStoreError.noBackup }
        return try Data(contentsOf: latestURL)
    }
}

enum BackupStoreError: LocalizedError {
    case noBackup
    var errorDescription: String? { "There is no saved original display configuration to restore." }
}

// MARK: - Plist editor

enum ResolutionPlistEditor {
    static func validate(width: Int, height: Int) throws {
        let product = width.multipliedReportingOverflow(by: height)
        guard (320...6000).contains(width), (320...6000).contains(height),
              !product.overflow, product.partialValue <= 25_000_000 else {
            throw ResolutionEditorError.outOfRange
        }
    }

    static func values(from data: Data) throws -> CanvasResolution? {
        let root: Any
        do { root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) }
        catch { throw ResolutionEditorError.invalidPropertyList }
        guard let dictionary = root as? [String: Any] else { throw ResolutionEditorError.invalidPropertyList }
        guard let width = (dictionary["canvas_width"] as? NSNumber)?.intValue,
              let height = (dictionary["canvas_height"] as? NSNumber)?.intValue else { return nil }
        return CanvasResolution(width: width, height: height)
    }

    static func applying(width: Int, height: Int, to data: Data) throws -> Data {
        try validate(width: width, height: height)
        let root: Any
        do { root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) }
        catch { throw ResolutionEditorError.invalidPropertyList }
        guard var dictionary = root as? [String: Any] else { throw ResolutionEditorError.invalidPropertyList }
        dictionary["canvas_width"] = NSNumber(value: width)
        dictionary["canvas_height"] = NSNumber(value: height)
        return try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
    }
}

// MARK: - Airlift FFI bridge

private typealias AirliftLogCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void


@_silgen_name("al_set_target_host")
private func cSetTargetHost(_ host: UnsafePointer<CChar>?) -> Int32

@_silgen_name("al_set_target_hosts")
private func cSetTargetHosts(_ hosts: UnsafePointer<UnsafePointer<CChar>?>?, _ count: Int) -> Int32

@_silgen_name("al_clear_target_hosts")
private func cClearTargetHosts()

@_silgen_name("al_exploit_read_file")
private func cReadFile(
    _ pairingPath: UnsafePointer<CChar>?, _ iosPath: UnsafePointer<CChar>?,
    _ logCallback: AirliftLogCallback?, _ context: UnsafeMutableRawPointer?,
    _ outputData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?,
    _ outputLength: UnsafeMutablePointer<Int>?,
    _ outputError: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32

@_silgen_name("al_bytes_free")
private func cBytesFree(_ pointer: UnsafeMutablePointer<UInt8>?, _ length: Int)

@_silgen_name("al_string_free")
private func cStringFree(_ pointer: UnsafeMutablePointer<CChar>?)

@_silgen_name("al_exploit_write_dir")
private func cWriteDirectory(
    _ pairingPath: UnsafePointer<CChar>?, _ sourceDirectory: UnsafePointer<CChar>?,
    _ targetDirectory: UnsafePointer<CChar>?, _ logCallback: AirliftLogCallback?,
    _ context: UnsafeMutableRawPointer?,
    _ outputError: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
) -> Int32

enum AirliftBridgeError: LocalizedError {
    case missingPairingFile, operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingPairingFile: return "Import a valid pairing file before using Airlift."
        case .operationFailed(let message): return message
        }
    }
}

private final class AirliftLogBuffer {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(line)
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private let airliftLogCallback: AirliftLogCallback = { context, message in
    guard let context, let message else { return }
    let buffer = Unmanaged<AirliftLogBuffer>.fromOpaque(context).takeUnretainedValue()
    buffer.append(String(cString: message))
}

enum AirliftBridge {
    private static let routeConfigurationLock = NSLock()
    private static var configuredTargetHost: String?

    // iOS 17+ stores managed mobile preferences under this path.
    // Nugget's resolution editor uses the same canonical location.
    static let targetFile = "/var/Managed Preferences/mobile/com.apple.iokit.IOMobileGraphicsFamily.plist"
    private static let targetDirectory = "/var/Managed Preferences/mobile"
    static func readDisplayConfiguration(pairingURL: URL?, targetHost: String) async throws -> Data {
        guard let pairingURL else { throw AirliftBridgeError.missingPairingFile }
        return try await Task.detached(priority: .userInitiated) {
            try readSynchronously(pairingPath: pairingURL.path, remotePath: targetFile, targetHost: targetHost)
        }.value
    }

    static func writeDisplayConfiguration(_ data: Data, pairingURL: URL?, targetHost: String) async throws {
        guard let pairingURL else { throw AirliftBridgeError.missingPairingFile }
        try await Task.detached(priority: .userInitiated) {
            try writeSynchronously(data, pairingPath: pairingURL.path, remotePath: targetFile, targetHost: targetHost)
        }.value
    }

    private static func configureTunnel(targetHost: String) throws {
        let normalizedHost = targetHost.trimmingCharacters(in: .whitespacesAndNewlines)
        var address = in_addr()
        guard normalizedHost.withCString({ inet_pton(AF_INET, $0, &address) }) == 1 else {
            throw AirliftBridgeError.operationFailed("Enter a valid IPv4 connection address, for example 10.7.1.1.")
        }

        // Airlift caches its last working RSD route. Clear that cache only when
        // the user changes the configured endpoint, otherwise keep fast reconnects.
        routeConfigurationLock.lock()
        defer { routeConfigurationLock.unlock() }

        if configuredTargetHost != normalizedHost {
            cClearTargetHosts()
        }

        let primaryResult = normalizedHost.withCString { cSetTargetHost($0) }
        guard primaryResult == 0 else {
            throw AirliftBridgeError.operationFailed(
                "Airlift could not configure its primary VPN target (code \(primaryResult))."
            )
        }

        configuredTargetHost = normalizedHost

        // AirCard's Airlift dialer supports multiple host candidates. Supplying
        // the active Wi-Fi/LAN addresses avoids relying on a single hard-coded IP.
        let candidates = NetworkStatus.tunnelHostCandidates()
        let allocated = candidates.map { strdup($0) }
        defer {
            allocated.forEach { pointer in
                if let pointer { free(pointer) }
            }
        }

        let pointers: [UnsafePointer<CChar>?] = allocated.map { pointer in
            pointer.map { UnsafePointer($0) }
        }
        if !pointers.isEmpty {
            let result = pointers.withUnsafeBufferPointer { buffer in
                cSetTargetHosts(buffer.baseAddress, buffer.count)
            }
            guard result == 0 else {
                throw AirliftBridgeError.operationFailed(
                    "Airlift could not register network host candidates (code \(result))."
                )
            }
        }
    }

    private static func readSynchronously(pairingPath: String, remotePath: String, targetHost: String) throws -> Data {
        try configureTunnel(targetHost: targetHost)
        let logs = AirliftLogBuffer()
        let context = Unmanaged.passUnretained(logs).toOpaque()

        var output: UnsafeMutablePointer<UInt8>?
        var outputLength = 0
        var outputError: UnsafeMutablePointer<CChar>?

        let result = pairingPath.withCString { pairing in
            remotePath.withCString { path in
                cReadFile(
                    pairing,
                    path,
                    airliftLogCallback,
                    context,
                    &output,
                    &outputLength,
                    &outputError
                )
            }
        }

        let message = consumeError(outputError)
        guard result == 0, let output else {
            throw AirliftBridgeError.operationFailed(
                diagnosticError(message, fallback: "Airlift read failed (code \(result)).", logs: logs)
            )
        }

        defer { cBytesFree(output, outputLength) }
        return Data(bytes: output, count: outputLength)
    }

    private static func writeSynchronously(_ data: Data, pairingPath: String, remotePath: String, targetHost: String) throws {
        try configureTunnel(targetHost: targetHost)
        let leaf = URL(fileURLWithPath: remotePath).lastPathComponent
        let stage = FileManager.default.temporaryDirectory
            .appendingPathComponent("67-Airlift-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stage) }
        try data.write(to: stage.appendingPathComponent(leaf), options: .atomic)

        let logs = AirliftLogBuffer()
        let context = Unmanaged.passUnretained(logs).toOpaque()
        var outputError: UnsafeMutablePointer<CChar>?

        let result = pairingPath.withCString { pairing in
            stage.path.withCString { source in
                targetDirectory.withCString { target in
                    cWriteDirectory(
                        pairing,
                        source,
                        target,
                        airliftLogCallback,
                        context,
                        &outputError
                    )
                }
            }
        }

        let message = consumeError(outputError)
        guard result == 0 else {
            throw AirliftBridgeError.operationFailed(
                diagnosticError(message, fallback: "Airlift write failed (code \(result)).", logs: logs)
            )
        }
    }

    private static func diagnosticError(
        _ message: String?,
        fallback: String,
        logs: AirliftLogBuffer
    ) -> String {
        let primary = friendlyError(message, fallback: fallback)
        let trace = logs.snapshot().suffix(14).joined(separator: "\n")
        guard !trace.isEmpty else { return primary }
        return primary + "\n\nAirlift diagnostic log:\n" + trace
    }

    private static func friendlyError(_ message: String?, fallback: String) -> String {
        guard let message else { return fallback }
        if message.localizedCaseInsensitiveContains("channel closed") {
            return message + "\nAirTraffic closed its channel. The diagnostic log below identifies the last successful Airlift stage; VPN route detection alone does not prove the device session is alive."
        }
        return message
    }

    private static func consumeError(_ pointer: UnsafeMutablePointer<CChar>?) -> String? {
        guard let pointer else { return nil }
        defer { cStringFree(pointer) }
        return String(cString: pointer)
    }
}
