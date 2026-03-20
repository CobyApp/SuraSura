import ComposableArchitecture
import APIClient
import Foundation

@Reducer
public struct TranslationReducer {

    @ObservableState
    public struct State: Equatable {
        public var translatedText: String = ""
        public var isTranslating: Bool = false
        public var isSpeaking: Bool = false
        public var targetLanguage: SupportedLanguage = .english
        public var errorMessage: String? = nil

        public init() {}
    }

    public enum Action {
        case translateRequested(String)
        case translationCompleted(String)
        case speakRequested
        case speakingFinished
        case stopSpeaking
        case languageChanged(SupportedLanguage)
        case errorOccurred(String)
    }

    @Dependency(\.googleTranslationClient) var translationClient
    @Dependency(\.ttsClient) var ttsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .translateRequested(let text):
                guard !text.isEmpty else { return .none }
                state.isTranslating = true
                let targetLang = state.targetLanguage
                return .run { send in
                    do {
                        let result = try await translationClient.translate(text, targetLang)
                        await send(.translationCompleted(result))
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .translationCompleted(let text):
                state.isTranslating = false
                state.translatedText = text
                // 번역 완료 즉시 TTS 자동 재생
                return .send(.speakRequested)

            case .speakRequested:
                guard !state.translatedText.isEmpty else { return .none }
                state.isSpeaking = true
                let text = state.translatedText
                let language = state.targetLanguage
                return .run { send in
                    do {
                        try await ttsClient.speak(text, language)
                    } catch {
                        // TTS 실패해도 앱은 계속 동작
                    }
                    await send(.speakingFinished)
                }

            case .speakingFinished:
                state.isSpeaking = false
                return .none

            case .stopSpeaking:
                state.isSpeaking = false
                ttsClient.stop()
                return .none

            case .languageChanged(let language):
                state.targetLanguage = language
                return .none

            case .errorOccurred(let message):
                state.isTranslating = false
                state.errorMessage = message
                return .none
            }
        }
    }
}
