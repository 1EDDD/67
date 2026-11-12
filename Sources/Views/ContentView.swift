import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var pairingController = PairingController.shared
    @AppStorage("localDevVPNConfirmed") private var localVPNEnabled = false
    @AppStorage("pendingSpringBoardRespring") private var restartRequired = false

    @State private var widthText = "2048"
    @State private var heightText = "1536"
    @State private var pairingName = PairingStore.currentFileName
    @State private var currentResolution = "Not read yet"
    @State private var status = "Import your pairing file and enable LocalDevVPN to begin."
    @State private var isError = false
    @State private var busy = false
    @State private var importingPairing = false
    @State private var confirmRespring = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var ready: Bool {
        PairingStore.currentURL != nil && localVPNEnabled && !busy
    }

    private var selected: CanvasResolution? {
        guard let width = Int(widthText), let height = Int(heightText) else { return nil }
        return CanvasResolution(width: width, height: height)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    editorCard
                    presetCard
                    connectionCard
                    actionsCard
                    restartCard
                    statusCard
                }
                .padding(18)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Resolution Studio")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: $importingPairing,
                allowedContentTypes: [.data, .propertyList],
                allowsMultipleSelection: false
            ) { result in
                importPairing(result)
            }
            .alert("Resolution Studio", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .confirmationDialog(
                "Respring SpringBoard?",
                isPresented: $confirmRespring,
                titleVisibility: .visible
            ) {
                Button("Respring SpringBoard", role: .destructive) {
                    runRespring()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This uses Erosion's WebView respring method. The display may go black or freeze temporarily while SpringBoard restarts. Use it only after rebooting the iPad.")
            }
        }
        .tint(.cyan)
        .onAppear {
            pairingName = PairingStore.currentFileName
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("DISPLAY CONTROL", systemImage: "display")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(.cyan)

            Text("Custom Resolution")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Edit canvas dimensions while preserving the rest of the display property list.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Canvas dimensions")
                    .font(.headline)
                Spacer()
                if let selected {
                    Text(selected.orientationLabel.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.cyan.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 12) {
                numberField("WIDTH", value: $widthText)
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                numberField("HEIGHT", value: $heightText)
            }

            HStack {
                if let selected {
                    Label(selected.megapixels, systemImage: "square.grid.3x3")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Enter two whole numbers", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                Button {
                    let previous = widthText
                    widthText = heightText
                    heightText = previous
                } label: {
                    Label("Rotate", systemImage: "rotate.3d")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(busy)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func numberField(_ title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            TextField("2048", text: value)
                .font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit())
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 13))
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Presets")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(ResolutionPreset.all) { preset in
                        Button {
                            widthText = String(preset.resolution.width)
                            heightText = String(preset.resolution.height)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(preset.name)
                                    .font(.caption.weight(.semibold))
                                Text(preset.resolution.displayValue)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minWidth: 125, alignment: .leading)
                            .padding(12)
                            .background(
                                selected == preset.resolution
                                    ? Color.cyan.opacity(0.16)
                                    : Color(uiColor: .secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        selected == preset.resolution ? Color.cyan.opacity(0.8) : Color.clear,
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(busy)
                    }
                }
            }
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Airlift connection")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(ready ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(ready ? "READY" : "SETUP REQUIRED")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ready ? .green : .orange)
            }

            HStack(spacing: 10) {
                Image(systemName: "doc.badge.gearshape")
                    .font(.title3)
                    .foregroundStyle(.cyan)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Pairing record")
                        .font(.subheadline.weight(.semibold))
                    Text(pairingName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button("Import") {
                    importingPairing = true
                }
                .buttonStyle(.bordered)
                .disabled(busy)
            }

            Button {
                Task { await pairTargetDevice() }
            } label: {
                HStack {
                    if pairingController.running {
                        ProgressView()
                    } else {
                        Image(systemName: "link.badge.plus")
                    }
                    Text(pairingController.running ? "Pairing…" : "Pair an iPad")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(busy || pairingController.running)

            if pairingController.running || pairingController.pairingStatus != "idle" {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pairingController.pairingStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let pin = pairingController.pairingPIN {
                        Text(pin)
                            .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.cyan)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 13))
            }

            Divider()

            Toggle(isOn: $localVPNEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LocalDevVPN is enabled")
                        .font(.subheadline.weight(.semibold))
                    Text("Enable the loopback VPN before reading or writing the iPad file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.green)
            .disabled(busy)

            Text("Pair the target iPad from Settings › Privacy & Security › Developer Mode. After pairing, enable LocalDevVPN and connect through 10.7.0.1.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            Button {
                Task { await readCurrent() }
            } label: {
                Label("Read current resolution", systemImage: "arrow.down.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!ready)

            Button {
                Task { await applyResolution() }
            } label: {
                HStack {
                    if busy {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(busy ? "Working…" : "Apply resolution")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(!ready || selected == nil)

            Button {
                Task { await restoreBackup() }
            } label: {
                Label("Restore saved backup", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!ready || !BackupStore.hasBackup)
        }
    }

    private var restartCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(.cyan)
                Text("Restart required")
                    .font(.headline)
                Spacer()
                if restartRequired {
                    Text("PENDING")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }

            Text("After Apply succeeds, reboot the iPad manually. When it has started again, open this app and respring SpringBoard.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                confirmRespring = true
            } label: {
                Label("Respring SpringBoard", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!restartRequired || busy)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("DEVICE STATUS")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            Text(currentResolution)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()

            Text(status)
                .font(.caption)
                .foregroundStyle(isError ? .red : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private func importPairing(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let saved = try PairingStore.importFile(from: url)
            pairingName = saved.lastPathComponent
            isError = false
            status = "Pairing record imported. Enable LocalDevVPN to connect."
        } catch {
            present(error)
        }
    }


    @MainActor
    private func pairTargetDevice() async {
        busy = true
        defer { busy = false }

        do {
            let path = try await pairingController.startAndWait()
            let saved = try PairingStore.importFile(from: URL(fileURLWithPath: path))
            pairingName = saved.lastPathComponent
            isError = false
            status = "Pairing succeeded. Enable LocalDevVPN, then read the current resolution."
        } catch {
            present(error)
        }
    }

    @MainActor
    private func readCurrent() async {
        guard let pairing = PairingStore.currentURL else {
            present(AirliftBridgeError.missingPairingFile)
            return
        }

        busy = true
        defer { busy = false }

        do {
            let data = try await AirliftBridge.readDisplayConfiguration(pairingURL: pairing)
            try BackupStore.save(data)

            if let resolution = try ResolutionPlistEditor.values(from: data) {
                currentResolution = resolution.displayValue
                widthText = String(resolution.width)
                heightText = String(resolution.height)
                status = "Read succeeded. A local backup of the current plist was saved."
            } else {
                currentResolution = "Canvas keys not found"
                status = "The file was read, but canvas_width or canvas_height was not present."
            }
            isError = false
        } catch {
            present(error)
        }
    }

    @MainActor
    private func applyResolution() async {
        guard let pairing = PairingStore.currentURL else {
            present(AirliftBridgeError.missingPairingFile)
            return
        }

        guard let width = Int(widthText), let height = Int(heightText) else {
            present(ResolutionEditorError.invalidNumber)
            return
        }

        busy = true
        defer { busy = false }

        do {
            try ResolutionPlistEditor.validate(width: width, height: height)
            let original = try await AirliftBridge.readDisplayConfiguration(pairingURL: pairing)
            try BackupStore.save(original)
            let modified = try ResolutionPlistEditor.applying(width: width, height: height, to: original)

            do {
                try await AirliftBridge.writeDisplayConfiguration(modified, pairingURL: pairing)
                let verified = try await AirliftBridge.readDisplayConfiguration(pairingURL: pairing)

                guard let actual = try ResolutionPlistEditor.values(from: verified),
                      actual == CanvasResolution(width: width, height: height) else {
                    throw ResolutionEditorError.verificationFailed
                }
            } catch {
                try? await AirliftBridge.writeDisplayConfiguration(original, pairingURL: pairing)
                throw error
            }

            currentResolution = "\(width) × \(height)"
            restartRequired = true
            isError = false
            status = "The new values were written and read back successfully. Restart the iPad to load them."
        } catch {
            present(error)
        }
    }

    @MainActor
    private func restoreBackup() async {
        guard let pairing = PairingStore.currentURL else {
            present(AirliftBridgeError.missingPairingFile)
            return
        }

        busy = true
        defer { busy = false }

        do {
            let backup = try BackupStore.loadLatest()
            try await AirliftBridge.writeDisplayConfiguration(backup, pairingURL: pairing)
            let verified = try await AirliftBridge.readDisplayConfiguration(pairingURL: pairing)
            guard verified == backup else { throw ResolutionEditorError.verificationFailed }

            if let resolution = try ResolutionPlistEditor.values(from: verified) {
                currentResolution = resolution.displayValue
            }

            restartRequired = true
            isError = false
            status = "The saved plist was restored and verified. Restart the iPad to load it."
        } catch {
            present(error)
        }
    }


    @MainActor
    private func runRespring() {
        guard NeoSpring.trigger() else {
            present(AirliftBridgeError.operationFailed("Could not find an active app window for the respring view."))
            return
        }
        restartRequired = false
        isError = false
        status = "SpringBoard respring was triggered."
    }

    @MainActor
    private func present(_ error: Error) {
        isError = true
        status = error.localizedDescription
        alertMessage = error.localizedDescription
        showAlert = true
    }
}
