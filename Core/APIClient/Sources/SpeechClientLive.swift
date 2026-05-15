import Foundation
import AVFoundation
import Speech

// Apple Speech Framework (on-device only)
// @unchecked Sendable: AVAudioEngine, SFSpeechRecognitionTask 등 non-Sendable 보유

final class SpeechClientLive: @unchecked Sendable {

    static let shared = SpeechClientLive()

    private var audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private init() {}

    func startStreaming(_ language: SupportedLanguage) throws -> AsyncStream<String> {
        let locale = language.sttLocale

        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.supportsOnDeviceRecognition,
              recognizer.isAvailable else {
            throw SpeechClientError.onDeviceRecognitionUnavailable
        }
        self.recognizer = recognizer

        return AsyncStream { continuation in
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { await self?.stopStreaming() }
            }

            Task {
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                request.requiresOnDeviceRecognition = true
                self.recognitionRequest = request

                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)

                    let inputNode = self.audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)

                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                        request.append(buffer)
                    }
                    try self.audioEngine.start()
                } catch {
                    try? AVAudioSession.sharedInstance().setActive(false)
                    continuation.finish()
                    return
                }

                self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    if let result = result {
                        continuation.yield(result.bestTranscription.formattedString)
                    }
                    if error != nil || result?.isFinal == true {
                        continuation.finish()
                    }
                }
            }
        }
    }

    func stopStreaming() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
