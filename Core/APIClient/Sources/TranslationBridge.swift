import Foundation
import Translation

/// SwiftUI `.translationTask` modifier가 제공하는 `TranslationSession`을
/// Reducer의 dependency에서 호출 가능하도록 연결해주는 브리지.
@MainActor
public final class TranslationBridge {
    public static let shared = TranslationBridge()
    private init() {}

    private var session: TranslationSession?
    private var registeredSource: SupportedLanguage?
    private var registeredTarget: SupportedLanguage?

    public func register(
        session: TranslationSession,
        source: SupportedLanguage,
        target: SupportedLanguage
    ) {
        self.session = session
        self.registeredSource = source
        self.registeredTarget = target
    }

    public func translate(
        text: String,
        source: SupportedLanguage,
        target: SupportedLanguage
    ) async throws -> String {
        // session이 준비될 때까지 최대 10초 대기.
        // 첫 사용 시 Apple이 모델 다운로드 동의 다이얼로그를 띄우므로 넉넉히 둠.
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while session == nil || registeredSource != source || registeredTarget != target {
            if ContinuousClock.now >= deadline {
                throw AppleTranslationError.sessionNotReady
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard let session = session else {
            throw AppleTranslationError.sessionNotReady
        }

        do {
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            throw AppleTranslationError.translationFailed
        }
    }
}

public enum AppleTranslationError: LocalizedError {
    case sessionNotReady
    case translationFailed

    public var errorDescription: String? {
        switch self {
        case .sessionNotReady:    return "번역 세션이 준비되지 않았습니다."
        case .translationFailed:  return "번역에 실패했습니다."
        }
    }
}
