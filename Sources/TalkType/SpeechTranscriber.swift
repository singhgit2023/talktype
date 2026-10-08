import AVFoundation
import Speech
import Foundation

final class SpeechTranscriber {
    private let engine = AVAudioEngine()
    private let requestLock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var requestGeneration = 0
    private var finished = false
    private var stopping = false
    private var tapInstalled = false
    private var confirmedText = ""
    private var latestSegment = ""
    private var latestText = ""
    private var consecutiveTransientErrors = 0
    var onText: ((String) -> Void)?
    var onLevel: ((Float) -> Void)?
    var onComplete: ((Result<String, Error>) -> Void)?
    private var lastLevelUpdate: CFAbsoluteTime = 0

    static func microphoneAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    static func speechAllowed() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default: return false
        }
    }

    func start(localeID: String, microphoneID: UInt32) throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)), recognizer.isAvailable else {
            throw TalkTypeError.recognitionUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else { throw TalkTypeError.onDeviceUnavailable }
        self.recognizer = recognizer

        try AudioInput.select(microphoneID, for: engine)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let levelCallback = onLevel
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.append(buffer)
            let now = CFAbsoluteTimeGetCurrent()
            guard now - self.lastLevelUpdate > 0.12,
                  let samples = buffer.floatChannelData?[0] else { return }
            self.lastLevelUpdate = now
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var energy: Float = 0
            var sampleCount = 0
            for index in stride(from: 0, to: count, by: 8) {
                energy += samples[index] * samples[index]
                sampleCount += 1
            }
            let level = min(1, sqrt(energy / Float(sampleCount)) * 7)
            DispatchQueue.main.async { levelCallback?(level) }
        }
        tapInstalled = true
        beginRecognition()
        engine.prepare()
        do {
            try engine.start()
        } catch {
            cancel()
            throw error
        }
    }

    func stop() {
        guard !finished, !stopping else { return }
        stopping = true
        if engine.isRunning { engine.stop() }
        removeTap()
        requestLock.lock()
        request?.endAudio()
        requestLock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, !self.finished else { return }
            self.finish(self.latestText.isEmpty ? .failure(TalkTypeError.noSpeech) : .success(self.latestText))
        }
    }

    func cancel() {
        finished = true
        if engine.isRunning { engine.stop() }
        removeTap()
        recognitionTask?.cancel()
        recognitionTask = nil
        requestLock.lock()
        request = nil
        requestLock.unlock()
    }

    private func beginRecognition(after delay: TimeInterval = 0) {
        guard let recognizer, !finished else { return }
        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.requiresOnDeviceRecognition = true
        newRequest.taskHint = .dictation
        requestGeneration += 1
        let generation = requestGeneration
        let replacingTask = recognitionTask != nil
        recognitionTask?.cancel()
        recognitionTask = nil
        requestLock.lock()
        request = newRequest
        requestLock.unlock()
        let launchTask = { [weak self] in
            guard let self, !self.finished, self.requestGeneration == generation else { return }
            self.recognitionTask = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self, !self.finished, self.requestGeneration == generation else { return }
                    if let result {
                        self.acceptSegment(result.bestTranscription.formattedString, isFinal: result.isFinal)
                        self.latestText = self.combinedText
                        if !self.latestText.isEmpty { self.onText?(self.latestText) }
                        if !self.latestSegment.isEmpty { self.consecutiveTransientErrors = 0 }
                        if result.isFinal {
                            if self.stopping { self.finish(.success(self.latestText)) }
                            else {
                                self.commitSegment()
                                self.beginRecognition(after: 0.22)
                            }
                        }
                    } else if let error {
                        if self.stopping, !self.latestText.isEmpty { self.finish(.success(self.latestText)) }
                        else if !self.stopping { self.handleRecognitionError(error) }
                        else { self.finish(.failure(error)) }
                    }
                }
            }
        }
        if replacingTask || delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + max(replacingTask ? 0.18 : 0, delay), execute: launchTask)
        }
        else { launchTask() }
    }

    private func acceptSegment(_ candidate: String, isFinal: Bool) {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let removedCount = latestSegment.count - trimmed.count
        if latestSegment.count >= 18, trimmed.count >= 3,
           removedCount > latestSegment.count / 2,
           !latestSegment.hasPrefix(trimmed) {
            // Some recognition tasks restart their partial text after a pause without a final callback.
            // Treat the new phrase as another segment rather than replacing the words already typed.
            commitSegment()
            latestSegment = trimmed
            return
        }
        // A pause can make the recognizer retract its latest partial. Keep words already shown.
        if removedCount > 4 && (isFinal || latestSegment.hasPrefix(trimmed)) { return }
        latestSegment = trimmed
    }

    private func handleRecognitionError(_ error: Error) {
        let code = error as NSError
        guard code.domain == "kAFAssistantErrorDomain" else { finish(.failure(error)); return }
        switch code.code {
        case 1110:
            // No speech in this segment is a pause, not the end of the user's recording.
            commitSegment()
            beginRecognition(after: 0.28)
        case 1100, 1101, 1107, 203:
            guard consecutiveTransientErrors < 3 else { finish(.failure(error)); return }
            consecutiveTransientErrors += 1
            commitSegment()
            beginRecognition(after: 0.28 * Double(consecutiveTransientErrors))
        default:
            finish(.failure(error))
        }
    }

    private var combinedText: String {
        let segment = latestSegment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !confirmedText.isEmpty else { return segment }
        guard !segment.isEmpty else { return confirmedText }
        return confirmedText + " " + segment
    }

    private func commitSegment() {
        confirmedText = combinedText
        latestSegment = ""
        latestText = confirmedText
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        requestLock.lock()
        request?.append(buffer)
        requestLock.unlock()
    }

    private func finish(_ result: Result<String, Error>) {
        guard !finished else { return }
        finished = true
        if engine.isRunning { engine.stop() }
        removeTap()
        recognitionTask?.cancel()
        recognitionTask = nil
        requestLock.lock()
        request = nil
        requestLock.unlock()
        onComplete?(result)
    }

    private func removeTap() {
        guard tapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }
}
