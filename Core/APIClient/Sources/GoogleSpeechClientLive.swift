import Foundation
import AVFoundation
import Speech

// MARK: - GoogleSpeechClientLive
// Apple Speech Framework (실시간 스트리밍) + Google STT REST (네팔어 등 배치)
// @unchecked Sendable: AVAudioEngine, SFSpeechRecognitionTask 등 non-Sendable 보유

final class GoogleSpeechClientLive: @unchecked Sendable {

    static let shared = GoogleSpeechClientLive()

    private let apiKey: String
    private var audioEngine = AVAudioEngine()

    // Apple Speech
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Google REST (배치용)
    private var googleAudioBuffer = Data()
    private var googleBatchTimer: Task<Void, Never>?

    private init(apiKey: String = APIKeys.googleCloud) {
        self.apiKey = apiKey
    }

    // MARK: - Start

    func startStreaming(_ language: SupportedLanguage) throws -> AsyncStream<String> {
        if let locale = language.appleSpeechLocale,
           SFSpeechRecognizer(locale: locale) != nil {
            return try startAppleStreaming(locale: locale)
        } else {
            return try startGoogleRestStreaming(language: language)
        }
    }

    // MARK: - Apple Speech (실시간)

    private func startAppleStreaming(locale: Locale) throws -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                guard let recognizer = SFSpeechRecognizer(locale: locale),
                      recognizer.isAvailable else {
                    continuation.finish()
                    return
                }

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
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

    // MARK: - Google STT REST (배치, 2초 단위)

    private func startGoogleRestStreaming(language: SupportedLanguage) throws -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)

                    let inputNode = self.audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)
                    let sampleRate = Int(format.sampleRate)

                    inputNode.installTap(onBus: 0, bufferSize: 8192, format: format) { buffer, _ in
                        guard let channelData = buffer.floatChannelData?[0] else { return }
                        let frameLength = Int(buffer.frameLength)
                        // Float32 → Int16 (LINEAR16)
                        var int16Data = [Int16](repeating: 0, count: frameLength)
                        for i in 0..<frameLength {
                            int16Data[i] = Int16(max(-1.0, min(1.0, channelData[i])) * Float(Int16.max))
                        }
                        self.googleAudioBuffer.append(contentsOf: Data(bytes: &int16Data, count: frameLength * 2))
                    }

                    try self.audioEngine.start()

                    // 2초마다 Google STT REST API 호출
                    self.googleBatchTimer = Task {
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(2))
                            let chunk = self.googleAudioBuffer
                            self.googleAudioBuffer = Data()
                            guard !chunk.isEmpty else { continue }
                            if let text = try? await GoogleSTTRestClient.recognize(
                                audioData: chunk,
                                language: language,
                                sampleRate: sampleRate,
                                apiKey: self.apiKey
                            ) {
                                continuation.yield(text)
                            }
                        }
                    }
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Stop

    func stopStreaming() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        googleBatchTimer?.cancel()
        googleBatchTimer = nil
        googleAudioBuffer = Data()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
