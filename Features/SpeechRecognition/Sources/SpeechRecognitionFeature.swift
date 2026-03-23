import ComposableArchitecture
import APIClient
import Foundation

// SpeechRecognitionReducer: 모듈명(SpeechRecognitionFeature)과 타입명 충돌 방지
@Reducer
public struct SpeechRecognitionReducer {

    @ObservableState
    public struct State: Equatable {
        public var recognizedText: String = ""
        public var isListening: Bool = false
        public var sourceLanguage: SupportedLanguage = .korean
        public var errorMessage: String? = nil

        public init() {}
    }

    public enum Action {
        case startListening
        case stopListening
        case recognizedTextUpdated(String)
        case languageChanged(SupportedLanguage)
        case errorOccurred(String)
    }

    @Dependency(\.googleSpeechClient) var speechClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .startListening:
                state.isListening = true
                state.recognizedText = ""
                let language = state.sourceLanguage
                return .run { send in
                    do {
                        for await text in try speechClient.startStreaming(language) {
                            await send(.recognizedTextUpdated(text))
                        }
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .stopListening:
                state.isListening = false
                return .run { _ in
                    await speechClient.stopStreaming()
                }

            case .recognizedTextUpdated(let text):
                // 빈 문자열 무시 - 세션 종료 시 인식기가 빈 값을 마지막으로 보내 텍스트가 지워지는 현상 방지
                if !text.isEmpty {
                    state.recognizedText = text
                }
                return .none

            case .languageChanged(let language):
                state.sourceLanguage = language
                return .none

            case .errorOccurred(let message):
                state.isListening = false
                state.errorMessage = message
                return .none
            }
        }
    }
}
