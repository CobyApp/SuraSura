import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct TranslationClient: Sendable {
    /// 텍스트 번역 요청 (source/target 모두 명시)
    public var translate: @Sendable (
        _ text: String,
        _ target: SupportedLanguage,
        _ source: SupportedLanguage
    ) async throws -> String = { _, _, _ in "" }
}

extension TranslationClient: DependencyKey {
    public static var liveValue: TranslationClient {
        TranslationClient(
            translate: { text, target, source in
                try await TranslationBridge.shared.translate(
                    text: text, source: source, target: target
                )
            }
        )
    }

    public static var previewValue: TranslationClient {
        TranslationClient(
            translate: { text, _, _ in "[\(text) 번역 미리보기]" }
        )
    }
}

extension DependencyValues {
    public var translationClient: TranslationClient {
        get { self[TranslationClient.self] }
        set { self[TranslationClient.self] = newValue }
    }
}
