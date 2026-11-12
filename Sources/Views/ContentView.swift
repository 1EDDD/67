import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var pairingController = PairingController.shared
    @AppStorage("hasShown67Instructions") private var hasShownInstructions = false
    @AppStorage("pendingSpringBoardRespring") private var restartRequired = false

    @State private var widthText = ""
    @State private var heightText = ""
    @State private var currentResolution = "—"
    @State private var status = "Pair your device or import a pairing file."
    @State private var pairingName = PairingStore.currentFileName
    @State private var vpnConnected = false
    @State private var busy = false
    @State private var importingPairing = false
    @State private var showInstructions = false
    @State private var showPresets = false
    @State private var selectedPresetCategory: PresetDeviceCategory?
    @State private var confirmRespring = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isError = false

    private var selectedResolution: CanvasResolution? {
        guard let width = Int(widthText), let height = Int(heightText) else { return nil }
        return CanvasResolution(width: width, height: height)
    }

    private var ready: Bool {
        PairingStore.currentURL != nil && vpnConnected && !busy
    }

    var body: some View {
        ZStack {
            Color(red: 0.015, green: 0.018, blue: 0.027).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    mascotHeader
                    resolutionFields
                    presetsButton
                    pairingCard
                    vpnCard
                    applyButton
                    respringButton
                    utilityActions
                    statusCard
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $importingPairing,
            allowedContentTypes: [.data, .propertyList],
            allowsMultipleSelection: false
        ) { result in
            importPairing(result)
        }
        .sheet(isPresented: $showPresets, onDismiss: { selectedPresetCategory = nil }) {
            presetsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .alert("67", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "Respring SpringBoard?",
            isPresented: $confirmRespring,
            titleVisibility: .visible
        ) {
            Button("Respring", role: .destructive) { runRespring() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use this only after saving the resolution and rebooting the device. SpringBoard may briefly disappear while it restarts.")
        }
        .overlay {
            if showInstructions {
                firstLaunchNotice
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            if !hasShownInstructions {
                showInstructions = true
            }
            while !Task.isCancelled {
                vpnConnected = NetworkStatus.localDevVPNIsConnected()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onChange(of: PairingStore.currentURL) { _, url in
            pairingName = url?.lastPathComponent ?? "No pairing file"
        }
    }

    // MARK: - Header

    private var mascotHeader: some View {
        VStack(spacing: 5) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(height: 132)
                .accessibilityLabel("67 mascot")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
    }

    // MARK: - Resolution editor

    private var resolutionFields: some View {
        HStack(spacing: 12) {
            dimensionField(title: "Width", value: $widthText)
            dimensionField(title: "Height", value: $heightText)
        }
    }

    private func dimensionField(title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("", text: value)
                .font(.system(size: 23, weight: .semibold, design: .rounded).monospacedDigit())
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .frame(height: 48)
                .padding(.horizontal, 13)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(cardBackground)
    }

    private var presetsButton: some View {
        Button {
            selectedPresetCategory = nil
            showPresets = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 25)
                Text("Presets")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 17)
            .frame(height: 58)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private var presetsSheet: some View {
        NavigationStack {
            Group {
                if let category = selectedPresetCategory {
                    List(DeviceResolutionPreset.all.filter { $0.category == category }) { preset in
                        Button {
                            widthText = String(preset.resolution.width)
                            heightText = String(preset.resolution.height)
                            showPresets = false
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.name)
                                        .foregroundStyle(.primary)
                                    Text(preset.resolution.displayValue)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedResolution == preset.resolution {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                        .listRowBackground(Color.white.opacity(0.045))
                    }
                    .listStyle(.plain)
                } else {
                    VStack(spacing: 14) {
                        categoryButton(.ipad, subtitle: "Landscape presets")
                        categoryButton(.iphone, subtitle: "Portrait presets")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.025, green: 0.03, blue: 0.045))
                }
            }
            .navigationTitle(selectedPresetCategory?.rawValue ?? "Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedPresetCategory != nil {
                        Button("Back") { selectedPresetCategory = nil }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showPresets = false }
                }
            }
        }
    }

    private func categoryButton(_ category: PresetDeviceCategory, subtitle: String) -> some View {
        Button {
            selectedPresetCategory = category
        } label: {
            HStack(spacing: 14) {
                Image(systemName: category == .ipad ? "ipad.landscape" : "iphone")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.cyan)
                    .frame(width: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pairing & VPN

    private var pairingCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 25)
                Text("Pairing")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button {
                    importingPairing = true
                } label: {
                    Label("File", systemImage: "doc")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(minWidth: 86, minHeight: 42)
                        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                }
                .disabled(busy || pairingController.running)

                Button {
                    Task { await pairTargetDevice() }
                } label: {
                    HStack(spacing: 7) {
                        if pairingController.running {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "link")
                        }
                        Text(pairingController.running ? "Pairing…" : "Pair")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(minWidth: 86, minHeight: 42)
                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                }
                .disabled(busy || pairingController.running)
            }
            .foregroundStyle(.white)
            .padding(15)

            if !pairingName.isEmpty || pairingController.running || pairingController.pairingStatus != "idle" {
                Divider().overlay(Color.white.opacity(0.06))
                VStack(alignment: .leading, spacing: 6) {
                    Text(pairingName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    if pairingController.running || pairingController.pairingStatus != "idle" {
                        Text(pairingController.pairingStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let pin = pairingController.pairingPIN {
                            Text(pin)
                                .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.cyan)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
        .background(cardBackground)
    }

    private var vpnCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 20))
                .frame(width: 25)
            Text("LocalDevVPN")
                .font(.system(size: 17, weight: .semibold))
            Spacer()
            Circle()
                .fill(vpnConnected ? Color.green : Color.gray)
                .frame(width: 9, height: 9)
            Text(vpnConnected ? "Connected" : "Disconnected")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(vpnConnected ? Color.green : Color.secondary)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 17)
        .frame(height: 60)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private var applyButton: some View {
        Button {
            Task { await applyResolution() }
        } label: {
            HStack(spacing: 10) {
                if busy {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                }
                Text(busy ? "Working…" : "Apply Resolution")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 63)
            .background(
                LinearGradient(colors: [Color(red: 0.08, green: 0.58, blue: 1),
                                        Color(red: 0.02, green: 0.31, blue: 0.98)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 17)
            )
        }
        .buttonStyle(.plain)
        .disabled(!ready || selectedResolution == nil)
        .opacity((!ready || selectedResolution == nil) ? 0.52 : 1)
    }

    private var respringButton: some View {
        Button {
            confirmRespring = true
        } label: {
            Label("Respring", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 59)
                .background(cardBackground)
        }
        .buttonStyle(.plain)
        .disabled(!restartRequired || busy)
        .opacity((!restartRequired || busy) ? 0.52 : 1)
    }

    private var utilityActions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await readCurrent() }
            } label: {
                Label("Read current", systemImage: "arrow.down.doc")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .disabled(!ready)

            Button {
                Task { await restoreBackup() }
            } label: {
                Label("Restore backup", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .disabled(!ready || !BackupStore.hasBackup)
        }
        .font(.system(size: 13, weight: .semibold))
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.85))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("DEVICE STATUS")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
                if restartRequired {
                    Text("RESTART REQUIRED")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }
            Text(currentResolution)
                .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(status)
                .font(.caption)
                .foregroundStyle(isError ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(cardBackground)
    }

    // MARK: - First launch notice

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

                        Divider().overlay(Color.white.opacity(0.16))
                            .padding(.vertical, 2)

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
                    withAnimation(.easeOut(duration: 0.2)) { showInstructions = false }
                } label: {
                    Text("موافق")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [Color.blue, Color(red: 0.02, green: 0.34, blue: 0.95)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: 460)
            .background(
                LinearGradient(colors: [Color(red: 0.08, green: 0.09, blue: 0.11),
                                        Color(red: 0.025, green: 0.03, blue: 0.045)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
            }
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
                .frame(width: 30, height: 30)
                .background(Color.blue.gradient, in: Circle())
        }
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 17)
            .fill(Color(red: 0.055, green: 0.065, blue: 0.085))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            }
    }

    // MARK: - Pairing

    @MainActor
    private func importPairing(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let saved = try PairingStore.importFile(from: url)
            pairingName = saved.lastPathComponent
            status = "Pairing file imported. Connect LocalDevVPN to continue."
            isError = false
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
            status = "Pairing succeeded. Connect LocalDevVPN to continue."
            isError = false
        } catch {
            present(error)
        }
    }

    // MARK: - Resolution operations

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
            if let resolution = try ResolutionPlistEditor.values(from: data) {
                currentResolution = resolution.displayValue
                widthText = String(resolution.width)
                heightText = String(resolution.height)
                status = "Current resolution read successfully."
                isError = false
            } else {
                throw ResolutionEditorError.invalidPropertyList
            }
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
            restartRequired = true
            status = "Resolution saved and verified. Reboot the device, reopen 67, then tap Respring."
            isError = false
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
            status = "Original display configuration restored and verified. Reboot the device."
            isError = false
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
        status = "Respring was triggered."
        isError = false
    }

    @MainActor
    private func present(_ error: Error) {
        isError = true
        status = error.localizedDescription
        alertMessage = error.localizedDescription
        showAlert = true
    }
}
