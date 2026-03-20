import AVFoundation
import Dependencies
import DependenciesMacros

// MARK: - TTSClient Interface

@DependencyClient
public struct TTSClient: Sendable {
    public var speak: @Sendable (_ text: String, _ language: SupportedLanguage) async throws -> Void = { _, _ in }
    public var stop: @Sendable () -> Void = {}
}

// MARK: - Dependency Registration

extension TTSClient: DependencyKey {
    public static var liveValue: TTSClient {
        let live = GoogleTTSClientLive.shared
        return TTSClient(
            speak: { text, language in try await live.speak(text: text, language: language) },
            stop: { live.stop() }
        )
    }

    public static var previewValue: TTSClient {
        TTSClient(speak: { _, _ in }, stop: {})
    }
}

extension DependencyValues {
    public var ttsClient: TTSClient {
        get { self[TTSClient.self] }
        set { self[TTSClient.self] = newValue }
    }
}
