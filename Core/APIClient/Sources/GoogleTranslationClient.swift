import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Client Interface

@DependencyClient
public struct GoogleTranslationClient: Sendable {
    /// 텍스트 번역 요청
    public var translate: @Sendable (
        _ text: String,
        _ targetLanguage: SupportedLanguage
    ) async throws -> String = { _, _ in "" }
}

// MARK: - Dependency Registration

extension GoogleTranslationClient: DependencyKey {
    public static var liveValue: GoogleTranslationClient {
        let apiKey = APIKeys.googleCloud
        return GoogleTranslationClient(
            translate: { text, targetLanguage in
                try await GoogleTranslationClientLive.translate(
                    text: text,
                    targetLanguage: targetLanguage,
                    apiKey: apiKey
                )
            }
        )
    }

    public static var previewValue: GoogleTranslationClient {
        GoogleTranslationClient(
            translate: { text, _ in "[\(text) 번역 미리보기]" }
        )
    }
}

extension DependencyValues {
    public var googleTranslationClient: GoogleTranslationClient {
        get { self[GoogleTranslationClient.self] }
        set { self[GoogleTranslationClient.self] = newValue }
    }
}
