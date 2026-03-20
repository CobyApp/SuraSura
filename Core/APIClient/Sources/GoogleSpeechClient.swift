import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Client Interface

@DependencyClient
public struct GoogleSpeechClient: Sendable {
    /// 실시간 스트리밍 STT 시작 - AsyncStream으로 인식 텍스트 방출
    public var startStreaming: @Sendable (_ language: SupportedLanguage) throws -> AsyncStream<String> = { _ in
        AsyncStream { _ in }
    }
    /// 스트리밍 중지
    public var stopStreaming: @Sendable () async -> Void = {}
}

// MARK: - Dependency Registration

extension GoogleSpeechClient: DependencyKey {
    public static var liveValue: GoogleSpeechClient {
        let live = GoogleSpeechClientLive.shared
        return GoogleSpeechClient(
            startStreaming: { language in
                try live.startStreaming(language)
            },
            stopStreaming: {
                await live.stopStreaming()
            }
        )
    }

    public static var previewValue: GoogleSpeechClient {
        GoogleSpeechClient(
            startStreaming: { _ in
                AsyncStream { continuation in
                    continuation.yield("안녕하세요 (미리보기)")
                    continuation.finish()
                }
            },
            stopStreaming: {}
        )
    }
}

extension DependencyValues {
    public var googleSpeechClient: GoogleSpeechClient {
        get { self[GoogleSpeechClient.self] }
        set { self[GoogleSpeechClient.self] = newValue }
    }
}
