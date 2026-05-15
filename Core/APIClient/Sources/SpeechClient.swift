import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Client Interface

@DependencyClient
public struct SpeechClient: Sendable {
    /// 실시간 스트리밍 STT 시작 - AsyncStream으로 인식 텍스트 방출
    public var startStreaming: @Sendable (_ language: SupportedLanguage) throws -> AsyncStream<String> = { _ in
        AsyncStream { _ in }
    }
    /// 스트리밍 중지
    public var stopStreaming: @Sendable () async -> Void = {}
}

// MARK: - Dependency Registration

extension SpeechClient: DependencyKey {
    public static var liveValue: SpeechClient {
        let live = SpeechClientLive.shared
        return SpeechClient(
            startStreaming: { language in
                try live.startStreaming(language)
            },
            stopStreaming: {
                await live.stopStreaming()
            }
        )
    }

    public static var previewValue: SpeechClient {
        SpeechClient(
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
    public var speechClient: SpeechClient {
        get { self[SpeechClient.self] }
        set { self[SpeechClient.self] = newValue }
    }
}

// MARK: - Errors

public enum SpeechClientError: LocalizedError, Sendable {
    case onDeviceRecognitionUnavailable

    public var errorDescription: String? {
        switch self {
        case .onDeviceRecognitionUnavailable:
            return "이 언어의 온디바이스 음성 인식을 사용할 수 없습니다."
        }
    }
}
