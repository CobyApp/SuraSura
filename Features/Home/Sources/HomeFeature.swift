import ComposableArchitecture
import SpeechRecognitionFeature
import TranslationFeature

public enum AppColorScheme: String, CaseIterable, Equatable {
    case system, light, dark
}

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
        // 번역 즉시 TTS
        public var isAutoSpeakEnabled: Bool = true
        // 커스텀 언어 피커 표시 여부
        public var isTopPickerPresented: Bool = false
        public var isBottomPickerPresented: Bool = false

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
        case autoSpeakToggled
        // 커스텀 피커
        case showTopPicker
        case hideTopPicker
        case showBottomPicker
        case hideBottomPicker
        // 텍스트 탭 → TTS
        case translationTextTapped
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
                let src = state.speechRecognition.sourceLanguage
                let tgt = state.translation.targetLanguage
                return .merge(
                    .send(.speechRecognition(.languageChanged(tgt))),
                    .send(.translation(.languageChanged(src)))
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

            case .autoSpeakToggled:
                state.isAutoSpeakEnabled.toggle()
                return .none

            case .showTopPicker:
                state.isTopPickerPresented = true
                return .none

            case .hideTopPicker:
                state.isTopPickerPresented = false
                return .none

            case .showBottomPicker:
                state.isBottomPickerPresented = true
                return .none

            case .hideBottomPicker:
                state.isBottomPickerPresented = false
                return .none

            case .translationTextTapped:
                guard !state.translation.translatedText.isEmpty else { return .none }
                return .send(state.translation.isSpeaking
                    ? .translation(.stopSpeaking)
                    : .translation(.speakRequested))

            // 번역 완료 → isAutoSpeakEnabled면 자동 TTS
            case .translation(.translationCompleted):
                guard state.isAutoSpeakEnabled else { return .none }
                return .send(.translation(.speakRequested))

            case .speechRecognition(.recognizedTextUpdated(let text)):
                return .send(.translation(.translateRequested(text)))

            case .speechRecognition, .translation:
                return .none
            }
        }
    }
}
