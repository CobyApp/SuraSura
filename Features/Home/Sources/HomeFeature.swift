import ComposableArchitecture
import SpeechRecognitionFeature
import TranslationFeature

public enum AppColorScheme: String, CaseIterable, Equatable {
    case system, light, dark
}

// HomeReducer: 모듈명(HomeFeature)과 타입명 충돌 방지
@Reducer
public struct HomeReducer {

    @ObservableState
    public struct State: Equatable {
        public var speechRecognition: SpeechRecognitionReducer.State = .init()
        public var translation: TranslationReducer.State = .init()
        public var isSessionActive: Bool = false
        public var isFaceToFaceMode: Bool = false
        public var appColorScheme: AppColorScheme = .system
        public var isSettingsPresented: Bool = false

        public init() {}
    }

    public enum Action {
        case speechRecognition(SpeechRecognitionReducer.Action)
        case translation(TranslationReducer.Action)
        case startSessionTapped
        case stopSessionTapped
        case swapLanguagesTapped
        case toggleFaceToFaceTapped
        case colorSchemeChanged(AppColorScheme)
        case settingsTapped
        case settingsDismissed
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

            case .swapLanguagesTapped:
                let oldSource = state.speechRecognition.sourceLanguage
                let oldTarget = state.translation.targetLanguage
                return .merge(
                    .send(.speechRecognition(.languageChanged(oldTarget))),
                    .send(.translation(.languageChanged(oldSource)))
                )

            case .toggleFaceToFaceTapped:
                state.isFaceToFaceMode.toggle()
                return .none

            case .colorSchemeChanged(let scheme):
                state.appColorScheme = scheme
                return .none

            case .settingsTapped:
                state.isSettingsPresented = true
                return .none

            case .settingsDismissed:
                state.isSettingsPresented = false
                return .none

            case .speechRecognition(.recognizedTextUpdated(let text)):
                return .send(.translation(.translateRequested(text)))

            case .speechRecognition, .translation:
                return .none
            }
        }
    }
}
