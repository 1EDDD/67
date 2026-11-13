import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var pairingController = PairingController.shared
    @AppStorage("hasShown67Instructions") private var hasShownInstructions = false
    @AppStorage("pendingSpringBoardRespring") private var restartRequired = false

    @State private var pairingName = PairingStore.currentFileName
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var currentResolution = "—"

    @State private var vpnRouteDetected = false
    @State private var airliftStatus = "Not verified"
    @State private var isReading = false
    @State private var isApplying = false
    @State private var isRestoring = false
    @State private var importingPairing = false
    @State private var showingPresets = false
    @State private var showingInstructions = false
    @State private var confirmingRespring = false
    @State private var showingError = false
    @State private var errorTitle = "67"
    @State private var errorMessage = ""
    @State private var statusMessage = ""
    @State private var hasError = false
    @State private var hasReadDevice = false

    private var selectedResolution: CanvasResolution? {
        guard let width = Int(widthText), let height = Int(heightText) else { return nil }
        return CanvasResolution(width: width, height: height)
    }

    private var canStartAirlift: Bool {
        PairingStore.currentURL != nil && vpnRouteDetected && !isReading && !isApplying && !isRestoring
    }

    private var isBusy: Bool {
        isReading || isApplying || isRestoring || pairingController.running
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image("Mascot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 82, height: 66)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("67")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("Resolution")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 3)
                    .listRowBackground(Color.clear)
                }

                Section("PAIRING") {
                    HStack(alignment: .center) {
                        Label("Pairing file", systemImage: "doc.text")
                        Spacer(minLength: 8)
                        Text(pairingName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack(spacing: 12) {
                        Button {
                            importingPairing = true
                        } label: {
                            Label("Import file", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isBusy)

                        Button {
                            Task { await pairTargetDevice() }
                        } label: {
                            HStack(spacing: 6) {
                                if pairingController.running {
                                    ProgressView()
                                } else {
                                    Image(systemName: "link")
                                }
                                Text(pairingController.running ? "Pairing…" : "Pair")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(isBusy)
                    }
                    .buttonStyle(.bordered)
                }

                Section("CONNECTION") {
                    statusRow(
                        title: "VPN route",
                        icon: "network",
                        value: vpnRouteDetected ? "Route detected" : "No route",
                        good: vpnRouteDetected
                    )

                    statusRow(
                        title: "Airlift",
                        icon: "arrow.left.arrow.right",
                        value: airliftStatus,
                        good: hasReadDevice
                    )

                    Button {
                        Task { await readCurrent() }
                    } label: {
                        HStack {
                            if isReading {
                                ProgressView()
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "arrow.down.doc")
                                    .foregroundStyle(.tint)
                            }
                            Text(isReading ? "Reading device…" : "Read device")
                            Spacer()
                            if hasReadDevice {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .disabled(!canStartAirlift)
                }

                if hasReadDevice {
                    Section("DEVICE RESOLUTION") {
                        HStack {
                            Text("Current")
                            Spacer()
                            Text(currentResolution)
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            dimensionField(title: "Width", value: $widthText)
                            dimensionField(title: "Height", value: $heightText)
                        }
                        .listRowSeparator(.hidden)

                        Button {
                            showingPresets = true
                        } label: {
                            Label("Presets", systemImage: "rectangle.on.rectangle")
                        }
                        .disabled(isBusy)

                        Button {
                            Task { await applyResolution() }
                        } label: {
                            HStack {
                                if isApplying {
                                    ProgressView().padding(.trailing, 4)
                                }
                                Text(isApplying ? "Applying…" : "Apply Resolution")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(!canStartAirlift || selectedResolution == nil)
                    }
                } else {
                    Section("DEVICE RESOLUTION") {
                        Label("Read the device first to show and edit its resolution.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("SYSTEM") {
                    if BackupStore.hasBackup {
                        Button {
                            Task { await restoreBackup() }
                        } label: {
                            HStack {
                                if isRestoring {
                                    ProgressView().padding(.trailing, 4)
                                }
                                Label("Restore backup", systemImage: "arrow.uturn.backward")
                            }
                        }
                        .disabled(!canStartAirlift)
                    }

                    if restartRequired {
                        Button(role: .destructive) {
                            confirmingRespring = true
                        } label: {
                            Label("Respring", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isBusy)
                    }
                }

                if !statusMessage.isEmpty {
                    Section("STATUS") {
                        if hasError {
                            DisclosureGroup("Connection details") {
                                Text(statusMessage)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        } else {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("67")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $importingPairing,
            allowedContentTypes: [.data, .propertyList],
            allowsMultipleSelection: false
        ) { result in
            importPairing(result)
        }
        .sheet(isPresented: $showingPresets) {
            PresetPickerView { preset in
                widthText = String(preset.resolution.width)
                heightText = String(preset.resolution.height)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert(errorTitle, isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            "Respring SpringBoard?",
            isPresented: $confirmingRespring,
            titleVisibility: .visible
        ) {
            Button("Respring", role: .destructive) {
                runRespring()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use this after applying the new resolution and restarting the device.")
        }
        .overlay {
            if showingInstructions {
                firstLaunchNotice
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            if !hasShownInstructions {
                showingInstructions = true
            }

            while !Task.isCancelled {
                let found = NetworkStatus.hasVPNRoute()
                if found != vpnRouteDetected {
                    vpnRouteDetected = found
                    if !found {
                        airliftStatus = "VPN route unavailable"
                    } else if !hasReadDevice {
                        airliftStatus = "Not verified"
                    }
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onChange(of: pairingName) { _, _ in
            hasReadDevice = false
            widthText = ""
            heightText = ""
            currentResolution = "—"
            airliftStatus = "Not verified"
        }
    }

    private func statusRow(title: String, icon: String, value: String, good: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(good ? Color.green : Color.secondary.opacity(0.6))
                    .frame(width: 7, height: 7)
                Text(value)
                    .font(.footnote)
                    .foregroundStyle(good ? Color.green : Color.secondary)
            }
        }
    }

    private func dimensionField(title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: value)
                .font(.title3.monospacedDigit())
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var firstLaunchNotice: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("خطوات تغيير الريزلوشن 🇸🇦")
                            .font(.system(size: 19, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)

                        Text("بعد ما تحفظ الريزلوشن الجديد بنجاح:")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)

                        instructionRow("أعد تشغيل جهازك.", number: "1", rtl: true)
                        instructionRow("افتح تطبيق 67.", number: "2", rtl: true)
                        instructionRow("اضغط على Respring.", number: "3", rtl: true)

                        Divider().padding(.vertical, 2)

                        Text("Steps to Change Resolution 🇺🇸")
                            .font(.system(size: 18, weight: .bold))
                        Text("After successfully saving the new resolution:")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        instructionRow("Reboot your device.", number: "1", rtl: false)
                        instructionRow("Open 67.", number: "2", rtl: false)
                        instructionRow("Tap Respring.", number: "3", rtl: false)
                    }
                    .padding(22)
                }
                .frame(maxHeight: 520)

                Button {
                    hasShownInstructions = true
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingInstructions = false
                    }
                } label: {
                    Text("موافق")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: 460)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 20)
        }
    }

    private func instructionRow(_ title: String, number: String, rtl: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor, in: Circle())
        }
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    // MARK: - Pairing

    @MainActor
    private func importPairing(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let saved = try PairingStore.importFile(from: url)
            pairingName = saved.lastPathComponent
            statusMessage = "Pairing file imported."
            hasError = false
        } catch {
            present(error)
        }
    }

    @MainActor
    private func pairTargetDevice() async {
        do {
            let path = try await pairingController.startAndWait()
            let saved = try PairingStore.importFile(from: URL(fileURLWithPath: path))
            pairingName = saved.lastPathComponent
            statusMessage = "Pairing succeeded. Read the device to verify the Airlift connection."
            hasError = false
        } catch {
            present(error)
        }
    }

    // MARK: - Device read / resolution apply

    @MainActor
    private func readCurrent() async {
        guard PairingStore.currentURL != nil else {
            present(AirliftBridgeError.missingPairingFile)
            return
        }
        guard vpnRouteDetected else {
            present(AirliftBridgeError.operationFailed("No VPN route to the configured device address was detected."))
            return
        }

        isReading = true
        hasReadDevice = false
        widthText = ""
        heightText = ""
        currentResolution = "—"
        airliftStatus = "Connecting…"
        statusMessage = "Opening the paired-device session and reading the display configuration."
        hasError = false
        defer { isReading = false }

        do {
            let data = try await AirliftBridge.readDisplayConfiguration(pairingURL: PairingStore.currentURL)
            guard let resolution = try ResolutionPlistEditor.values(from: data) else {
                throw ResolutionEditorError.invalidPropertyList
            }

            currentResolution = resolution.displayValue
            widthText = String(resolution.width)
            heightText = String(resolution.height)
            hasReadDevice = true
            airliftStatus = "Device verified"
            statusMessage = "Airlift read the device configuration successfully."
            hasError = false
        } catch {
            airliftStatus = "Connection failed"
            hasReadDevice = false
            present(error)
        }
    }

    @MainActor
    private func applyResolution() async {
        guard hasReadDevice else {
            present(ResolutionEditorError.invalidPropertyList)
            return
        }
        guard let pairing = PairingStore.currentURL else {
            present(AirliftBridgeError.missingPairingFile)
            return
        }
        guard let width = Int(widthText), let height = Int(heightText) else {
            present(ResolutionEditorError.invalidNumber)
            return
        }
        guard vpnRouteDetected else {
            present(AirliftBridgeError.operationFailed("The VPN route is no longer available. Reconnect the VPN and read the device again."))
            return
        }

        isApplying = true
        defer { isApplying = false }

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
                do {
                    try await AirliftBridge.writeDisplayConfiguration(original, pairingURL: pairing)
                } catch let rollbackError {
                    throw AirliftBridgeError.operationFailed(
                        "Apply failed: \(error.localizedDescription). Automatic restore also failed: \(rollbackError.localizedDescription). Keep the device connected and restore the saved backup."
                    )
                }
                throw error
            }

            currentResolution = "\(width) × \(height)"
            hasReadDevice = true
            restartRequired = true
            statusMessage = "Resolution saved and verified. Reboot the device, reopen 67, then tap Respring."
            hasError = false
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
        guard vpnRouteDetected else {
            present(AirliftBridgeError.operationFailed("The VPN route is unavailable."))
            return
        }

        isRestoring = true
        defer { isRestoring = false }

        do {
            let backup = try BackupStore.loadLatest()
            try await AirliftBridge.writeDisplayConfiguration(backup, pairingURL: pairing)
            let verified = try await AirliftBridge.readDisplayConfiguration(pairingURL: pairing)
            guard verified == backup else { throw ResolutionEditorError.verificationFailed }

            if let resolution = try ResolutionPlistEditor.values(from: verified) {
                currentResolution = resolution.displayValue
                widthText = String(resolution.width)
                heightText = String(resolution.height)
                hasReadDevice = true
            }
            restartRequired = true
            statusMessage = "Original display configuration restored and verified. Reboot the device."
            hasError = false
        } catch {
            present(error)
        }
    }

    @MainActor
    private func runRespring() {
        guard NeoSpring.trigger() else {
            present(AirliftBridgeError.operationFailed("The respring action could not be started. Reboot the device manually."))
            return
        }
        restartRequired = false
        statusMessage = "Respring attempt started. If SpringBoard does not restart, reboot the device manually."
        hasError = false
    }

    @MainActor
    private func present(_ error: Error) {
        let detail = error.localizedDescription
        hasError = true
        statusMessage = detail
        errorTitle = "Airlift"
        errorMessage = "The device operation could not be completed. Open Status → Connection details for the diagnostic trace."
        showingError = true
    }
}
