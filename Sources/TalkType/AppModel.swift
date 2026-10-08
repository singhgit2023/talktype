import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import Speech

@MainActor final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Phase: Equatable {
        case idle, preparing, listening, finishing, success, failure
    }
    private enum RecordingMode { case hold, button }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var liveText = ""
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var message = "Ready when you are"
    @Published private(set) var microphoneInputs = AudioInput.available()
    @Published var microphoneID: UInt32 {
        didSet { UserDefaults.standard.set(microphoneID, forKey: "microphoneID") }
    }
    @Published var languageID: String {
        didSet { UserDefaults.standard.set(languageID, forKey: "languageID") }
    }
    @Published var automaticFormatting: Bool {
        didSet { UserDefaults.standard.set(automaticFormatting, forKey: "automaticFormatting") }
    }
    @Published var mascotAnimations: Bool {
        didSet { UserDefaults.standard.set(mascotAnimations, forKey: "mascotAnimations") }
    }
    @Published var soundCuesEnabled: Bool {
        didSet { UserDefaults.standard.set(soundCuesEnabled, forKey: "soundCuesEnabled") }
    }
    @Published var shortcutChoice: ShortcutChoice {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(shortcutChoice), forKey: "customShortcut")
            shortcut.configure(shortcutChoice)
        }
    }
    @Published var panelAppearance: PanelAppearance {
        didSet { UserDefaults.standard.set(panelAppearance.rawValue, forKey: "panelAppearance") }
    }
    @Published var transcriptFontSize: Double {
        didSet { UserDefaults.standard.set(transcriptFontSize, forKey: "transcriptFontSize") }
    }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let shortcut = GlobalShortcut()
    private let soundCues = SoundCues()
    private var transcriber: SpeechTranscriber?
    private var injector: LiveTextInjector?
    private var pendingText: String?
    private var flushTask: Task<Void, Never>?
    private var acceptsPartials = false
    private var shortcutIsHeld = false
    private var recordingMode: RecordingMode = .button
    private var targetApp: NSRunningApplication?
    private var lastExternalApp: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?
    let listeningPanel = ListeningPanelController()

    private init() {
        let defaults = UserDefaults.standard
        microphoneID = UInt32(defaults.integer(forKey: "microphoneID"))
        languageID = defaults.string(forKey: "languageID") ?? "en-US"
        automaticFormatting = defaults.object(forKey: "automaticFormatting") as? Bool ?? true
        mascotAnimations = defaults.object(forKey: "mascotAnimations") as? Bool ?? true
        soundCuesEnabled = defaults.object(forKey: "soundCuesEnabled") as? Bool ?? true
        if let data = defaults.data(forKey: "customShortcut"), let saved = try? JSONDecoder().decode(ShortcutChoice.self, from: data) {
            shortcutChoice = saved
        } else { shortcutChoice = .controlCommand }
        panelAppearance = PanelAppearance(rawValue: defaults.string(forKey: "panelAppearance") ?? "") ?? .cream
        transcriptFontSize = defaults.object(forKey: "transcriptFontSize") as? Double ?? 14
        lastExternalApp = NSWorkspace.shared.frontmostApplication
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            Task { @MainActor in self?.lastExternalApp = app }
        }
        shortcut.configure(shortcutChoice)
    }

    var isRecording: Bool { phase == .listening || phase == .preparing || phase == .finishing }
    var hasCompletedOnboarding: Bool { UserDefaults.standard.integer(forKey: "onboardingVersion") >= 2 }
    var microphonePermission: Bool { AVCaptureDevice.authorizationStatus(for: .audio) == .authorized }
    var speechPermission: Bool { SFSpeechRecognizer.authorizationStatus() == .authorized }
    var accessibilityPermission: Bool { TextInjector.accessibilityIsGranted(prompt: false) }

    func completeOnboarding() {
        UserDefaults.standard.set(2, forKey: "onboardingVersion")
    }

    func suspendShortcut(_ suspended: Bool) { shortcut.suspended = suspended }

    func requestMicrophone() async { _ = await SpeechTranscriber.microphoneAllowed(); objectWillChange.send() }
    func requestSpeech() async { _ = await SpeechTranscriber.speechAllowed(); objectWillChange.send() }
    func requestAccessibility() { _ = TextInjector.accessibilityIsGranted(prompt: true); objectWillChange.send() }
    func showCompanion() {
        listeningPanel.show(model: self)
        if !isRecording { listeningPanel.hide(after: 5) }
    }
    func refreshMicrophones() { microphoneInputs = AudioInput.available() }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            fail(error)
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func toggleRecording() {
        if phase == .listening { stopRecording() }
        else if !isRecording { Task { await startRecording(mode: .button) } }
    }

    func shortcutPressed() {
        shortcutIsHeld = true
        guard !isRecording else { return }
        Task { await startRecording(mode: .hold) }
    }

    func shortcutReleased() {
        shortcutIsHeld = false
        if phase == .listening && recordingMode == .hold { stopRecording() }
    }

    private func startRecording(mode: RecordingMode) async {
        guard !isRecording else { return }
        guard mode != .hold || shortcutIsHeld else { return }
        recordingMode = mode
        phase = .preparing
        message = "Getting ready…"
        liveText = ""
        audioLevel = 0
        targetApp = NSWorkspace.shared.frontmostApplication.flatMap {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier ? lastExternalApp : $0
        } ?? lastExternalApp

        guard targetApp != nil else { fail(TalkTypeError.noTarget); return }
        guard await SpeechTranscriber.microphoneAllowed() else { fail(TalkTypeError.microphonePermission); return }
        guard await SpeechTranscriber.speechAllowed() else { fail(TalkTypeError.speechPermission); return }
        guard TextInjector.accessibilityIsGranted(prompt: true) else { fail(TalkTypeError.accessibilityPermission); return }
        guard mode != .hold || shortcutIsHeld else { phase = .idle; message = "Ready when you are"; return }

        guard let targetApp else { fail(TalkTypeError.noTarget); return }
        let injector = LiveTextInjector(app: targetApp)
        do { try await injector.prepare() }
        catch { fail(error); return }
        guard mode != .hold || shortcutIsHeld else { phase = .idle; message = "Ready when you are"; return }
        self.injector = injector
        acceptsPartials = true

        let transcriber = SpeechTranscriber()
        transcriber.onText = { [weak self] text in
            Task { @MainActor in self?.receivePartial(text) }
        }
        transcriber.onLevel = { [weak self] level in
            Task { @MainActor in self?.audioLevel = level }
        }
        transcriber.onComplete = { [weak self] result in
            Task { @MainActor in await self?.completeRecording(result) }
        }
        do {
            try transcriber.start(localeID: languageID, microphoneID: microphoneID)
            self.transcriber = transcriber
            phase = .listening
            message = "Listening…"
            listeningPanel.show(model: self)
            if soundCuesEnabled { soundCues.playStart() }
        } catch {
            transcriber.cancel()
            fail(error)
        }
    }

    func stopRecording() {
        guard phase == .listening else { return }
        phase = .finishing
        audioLevel = 0
        message = "Finishing your thought…"
        transcriber?.stop()
        if soundCuesEnabled { soundCues.playFinish() }
    }

    private func receivePartial(_ transcript: String) {
        guard acceptsPartials, phase == .listening || phase == .finishing else { return }
        let formatted = DictationFormatter.format(transcript, enabled: automaticFormatting, finalize: false)
        if !formatted.isEmpty { liveText = formatted }
        pendingText = formatted
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            guard let self else { return }
            while let next = self.pendingText {
                self.pendingText = nil
                do {
                    try await self.injector?.update(next)
                    if self.pendingText == nil { self.liveText = self.injector?.insertedText ?? next }
                } catch { self.fail(error); break }
            }
            self.flushTask = nil
        }
    }

    private func completeRecording(_ result: Result<String, Error>) async {
        guard phase == .listening || phase == .finishing else { return }
        acceptsPartials = false
        pendingText = nil
        transcriber = nil
        await flushTask?.value
        guard phase == .listening || phase == .finishing else { return }
        switch result {
        case .success(let transcript):
            let text = DictationFormatter.format(transcript, enabled: automaticFormatting)
            guard !text.isEmpty else { injector?.finish(); injector = nil; fail(TalkTypeError.noSpeech); return }
            do {
                try await injector?.update(text)
                let displayedText = injector?.insertedText ?? text
                injector?.finish()
                injector = nil
                phase = .success
                message = "Typed as you spoke!"
                liveText = displayedText
                listeningPanel.hide(after: 0.8)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard self?.phase == .success else { return }
                    self?.phase = .idle
                    self?.message = "Ready when you are"
                }
            } catch { fail(error) }
        case .failure(let error):
            injector?.finish()
            injector = nil
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        acceptsPartials = false
        pendingText = nil
        transcriber?.cancel()
        transcriber = nil
        injector?.finish()
        injector = nil
        phase = .failure
        message = error.localizedDescription
        listeningPanel.show(model: self)
        listeningPanel.hide(after: 5)
    }
}
