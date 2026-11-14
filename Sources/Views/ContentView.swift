import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @StateObject private var pairingController = PairingController.shared
    @AppStorage("hasShown67Instructions") private var hasShownInstructions = false
    @AppStorage("67AppLanguage") private var selectedLanguage = ""
    @AppStorage("pendingSpringBoardRespring") private var restartRequired = false

    @State private var pairingName = PairingStore.currentFileName
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var currentResolution = "—"

    @AppStorage("airliftTargetHost") private var targetHost = "10.7.0.1"
    @State private var airliftStatus = "Not verified"
    @State private var isReading = false
    @State private var isApplying = false
    @State private var isRestoring = false
    @State private var importingPairing = false
    @State private var showingPresets = false
    @State private var showingInstructions = false
    @State private var showingLanguagePicker = false
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
        PairingStore.currentURL != nil && !isBusy
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
                            Text("Resolution changer")
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
                    .buttonStyle(.plain)

                    if pairingController.running {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text(pairingController.pairingStatus)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Text("On your device: Settings → Privacy & Security → Developer Mode → Pair with 67")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if let pin = pairingController.pairingPIN {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("VERIFICATION CODE")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)

                                    HStack {
                                        Text(pin)
                                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                                            .monospacedDigit()
                                        Spacer()
                                        Button {
                                            UIPasteboard.general.string = pin
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.tint)
                                    }

                                }
                                .padding(14)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button(role: .destructive) {
                                pairingController.softCancel()
                            } label: {
                                Label("Cancel Pairing", systemImage: "xmark")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                    } else if pairingController.pairingStatus != "idle" {
                        Text(pairingController.pairingStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                    if hasReadDevice {
                    Section("DEVICE RESOLUTION") {
                        Button {
                            Task { await readCurrent() }
                        } label: {
                            HStack {
                                if isReading {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                } else {
                                    Image(systemName: "arrow.down.doc")
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
                        Button {
                            Task { await readCurrent() }
                        } label: {
                            HStack {
                                if isReading {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                } else {
                                    Image(systemName: "arrow.down.doc")
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
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    confirmingRespring = true
                } label: {
                    Label("Respring", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isBusy)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("67")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(uiColor: .secondarySystemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await readCurrent() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(hasReadDevice ? Color.green : Color.secondary)
                            .symbolEffect(
                                .rotate,
                                options: .repeating,
                                isActive: isReading || isApplying || isRestoring
                            )
                            .accessibilityLabel(
                                isReading ? "Airlift connecting" :
                                hasReadDevice ? "Airlift device verified" : "Read device with Airlift"
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStartAirlift)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBarHidden(UIDevice.current.userInterfaceIdiom == .phone)
        .fileImporter(
            isPresented: $importingPairing,
            allowedContentTypes: [.data, .propertyList],
            allowsMultipleSelection: false
        ) { result in
            importPairing(result)
        }
        .fullScreenCover(isPresented: $showingPresets) {
            PresetPickerView { preset in
                widthText = String(preset.resolution.width)
                heightText = String(preset.resolution.height)
            }
            .preferredColorScheme(.dark)
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
            if showingLanguagePicker {
                languagePickerNotice
                    .transition(.opacity)
                    .zIndex(10)
            } else if showingInstructions {
                firstLaunchNotice
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            if selectedLanguage.isEmpty {
                showingLanguagePicker = true
            } else if !hasShownInstructions {
                showingInstructions = true
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

    private var languagePickerNotice: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Choose Your Language")
                    .font(.system(size: 21, weight: .bold))
                Text("اختر اللغة")
                    .font(.system(size: 19, weight: .semibold))
                    .environment(\.layoutDirection, .rightToLeft)

                Button {
                    chooseLanguage("ar")
                } label: {
                    Text("العربية")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    chooseLanguage("en")
                } label: {
                    Text("English")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chooseLanguage(_ language: String) {
        selectedLanguage = language
        hasShownInstructions = false
        showingLanguagePicker = false
        withAnimation(.easeOut(duration: 0.2)) {
            showingInstructions = true
        }
    }

    private var firstLaunchNotice: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: selectedLanguage == "ar" ? .trailing : .leading, spacing: 18) {
                    if selectedLanguage == "ar" {
                        Text("خطوات تغيير الريزلوشن")
                            .font(.system(size: 20, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)

                        Text("بعد ما تحفظ الريزلوشن الجديد بنجاح:")
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)

                        instructionRow("أعد تشغيل جهازك.", number: "1", rtl: true)
                        instructionRow("افتح 67.", number: "2", rtl: true)
                        instructionRow("اضغط Respring.", number: "3", rtl: true)
                    } else {
                        Text("Steps to Change Resolution")
                            .font(.system(size: 20, weight: .bold))

                        Text("After successfully saving the new resolution:")
                            .font(.system(size: 16, weight: .medium))

                        instructionRow("Reboot your device.", number: "1", rtl: false)
                        instructionRow("Open 67.", number: "2", rtl: false)
                        instructionRow("Tap Respring.", number: "3", rtl: false)
                    }
                }
                .padding(24)

                Button {
                    hasShownInstructions = true
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingInstructions = false
                    }
                } label: {
                    Text(selectedLanguage == "ar" ? "فهمت" : "Got it")
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
            .frame(maxWidth: 360)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            hasReadDevice = false
            widthText = ""
            heightText = ""
            currentResolution = "—"
            airliftStatus = "Not verified"
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
            hasReadDevice = false
            widthText = ""
            heightText = ""
            currentResolution = "—"
            airliftStatus = "Not verified"
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
            let data = try await AirliftBridge.readDisplayConfiguration(pairingURL: PairingStore.currentURL, targetHost: targetHost)
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
        isApplying = true
        defer { isApplying = false }

        do {
            try ResolutionPlistEditor.validate(width: width, height: height)
            let original = try await AirliftBridge.readDisplayConfiguration(pairingURL: pairing, targetHost: targetHost)
            try BackupStore.save(original)

            let modified = try ResolutionPlistEditor.applying(width: width, height: height, to: original)
            do {
                try await AirliftBridge.writeDisplayConfiguration(modified, pairingURL: pairing, targetHost: targetHost)
                let verified = try await AirliftBridge.readDisplayConfiguration(pairingURL: pairing, targetHost: targetHost)
                guard let actual = try ResolutionPlistEditor.values(from: verified),
                      actual == CanvasResolution(width: width, height: height) else {
                    throw ResolutionEditorError.verificationFailed
                }
            } catch {
                do {
                    try await AirliftBridge.writeDisplayConfiguration(original, pairingURL: pairing, targetHost: targetHost)
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
        isRestoring = true
        defer { isRestoring = false }

        do {
            let backup = try BackupStore.loadLatest()
            try await AirliftBridge.writeDisplayConfiguration(backup, pairingURL: pairing, targetHost: targetHost)
            let verified = try await AirliftBridge.readDisplayConfiguration(pairingURL: pairing, targetHost: targetHost)
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
        hasError = true
        statusMessage = error.localizedDescription

        if let bridgeError = error as? AirliftBridgeError {
            switch bridgeError {
            case .missingPairingFile:
                errorTitle = selectedLanguage == "ar" ? "ملف الاقتران مطلوب" : "Pairing file required"
                errorMessage = selectedLanguage == "ar"
                    ? "يرجى استيراد ملف الاقتران أولاً."
                    : "Import a pairing file before using Airlift."
            case .operationFailed:
                errorTitle = "Airlift"
                errorMessage = selectedLanguage == "ar"
                    ? "تعذّر إكمال العملية عبر Airlift.\n(غالباً ملف الريزلوشن تالف. انتقل إلى الإعدادات ← الشاشة والإضاءة ← تكبير الشاشة، واختر الخيار الثاني، ثم حاول مرة أخرى.)"
                    : "Airlift operation failed.\n(Your resolution file may be corrupted. Go to Settings → Display & Brightness → Display Zoom, select the second option, then try again.)"
            }
        } else {
            errorTitle = selectedLanguage == "ar" ? "خطأ" : "Error"
            errorMessage = error.localizedDescription
        }

        showingError = true
    }
}
