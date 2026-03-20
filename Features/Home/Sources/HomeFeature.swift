import ComposableArchitecture
import SpeechRecognitionFeature
import TranslationFeature

// HomeReducer: 모듈명(HomeFeature)과 타입명 충돌 방지
@Reducer
public struct HomeReducer {

    @ObservableState
    public struct State: Equatable {
        public var speechRecognition: SpeechRecognitionReducer.State = .init()
        public var translation: TranslationReducer.State = .init()
        public var isSessionActive: Bool = false

        public init() {}
    }

    public enum Action {
        case speechRecognition(SpeechRecognitionReducer.Action)
        case translation(TranslationReducer.Action)
        case startSessionTapped
        case stopSessionTapped
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.speechRecognition, action: \.speechRecognition) {
            SpeechRecognitionReducer()
        }
        Scope(state: \.translation, action: \.translation) {
            TranslationReducer()
        }
        Reduce { state, action in
            switch action {
            case .startSessionTapped:
                state.isSessionActive = true
                return .send(.speechRecognition(.startListening))

            case .stopSessionTapped:
                state.isSessionActive = false
                return .send(.speechRecognition(.stopListening))

            case .speechRecognition(.recognizedTextUpdated(let text)):
                return .send(.translation(.translateRequested(text)))

            case .speechRecognition, .translation:
                return .none
            }
        }
    }
}
