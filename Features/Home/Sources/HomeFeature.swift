import Foundation
import ComposableArchitecture
import SpeechRecognitionFeature
import TranslationFeature
import APIClient

public enum AppColorScheme: String, CaseIterable, Equatable {
    case system, light, dark
}

public enum ActiveMic: String, Equatable, CaseIterable {
    case bottom, top
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
        public var isAutoSpeakEnabled: Bool = true
        // 커스텀 언어 피커
        public var isTopPickerPresented: Bool = false
        public var isBottomPickerPresented: Bool = false
        // 앱 내 언어 설정 ("" = 시스템 기본값)
        public var appLanguage: String = ""
        // 텍스트 전체화면 확장
        public var isTopExpanded: Bool = false
        public var isBottomExpanded: Bool = false
        // 상단/하단 패널 언어 (스왑 없이 직접 관리)
        public var topLanguage: SupportedLanguage = .english
        public var bottomLanguage: SupportedLanguage = .korean
        // 현재 활성 마이크 패널
        public var activeMic: ActiveMic = .bottom

        public init() {
            self.appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        }
    }

    public enum Action {
        case speechRecognition(SpeechRecognitionReducer.Action)
        case translation(TranslationReducer.Action)
        case startSessionTapped        // 하단 마이크
        case stopSessionTapped
        case startTopSessionTapped     // 상단 마이크
        case topLanguageChanged(SupportedLanguage)
        case bottomLanguageChanged(SupportedLanguage)
        case swapLanguagesTapped
        case toggleFaceToFaceTapped
        case colorSchemeChanged(AppColorScheme)
        case settingsTapped
        case settingsDismissed
        case autoSpeakToggled
        case appLanguageChanged(String)
        // 커스텀 피커
        case showTopPicker
        case hideTopPicker
        case showBottomPicker
        case hideBottomPicker
        // 텍스트 전체화면 확장
        case expandTopPanel
        case collapseTopPanel
        case expandBottomPanel
        case collapseBottomPanel
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

            // MARK: - 세션

            case .startSessionTapped:
                guard !state.isSessionActive else { return .none }
                // 하단 마이크: bottomLanguage로 인식 → topLanguage로 번역
                state.activeMic = .bottom
                state.isSessionActive = true
                state.translation.translatedText = ""   // 번역 초기화 (recognizedText는 startListening에서 초기화)
                state.speechRecognition.sourceLanguage = state.bottomLanguage
                state.translation.targetLanguage = state.topLanguage
                return .send(.speechRecognition(.startListening))

            case .startTopSessionTapped:
                guard !state.isSessionActive else { return .none }
                // 상단 마이크: topLanguage로 인식 → bottomLanguage로 번역
                state.activeMic = .top
                state.isSessionActive = true
                state.translation.translatedText = ""   // 번역 초기화 (recognizedText는 startListening에서 초기화)
                state.speechRecognition.sourceLanguage = state.topLanguage
                state.translation.targetLanguage = state.bottomLanguage
                return .send(.speechRecognition(.startListening))

            case .stopSessionTapped:
                state.isSessionActive = false
                return .send(.speechRecognition(.stopListening))

            // MARK: - 언어 선택

            case .topLanguageChanged(let lang):
                state.topLanguage = lang
                state.speechRecognition.recognizedText = ""
                state.translation.translatedText = ""
                if state.activeMic == .bottom {
                    state.translation.targetLanguage = lang
                } else {
                    state.speechRecognition.sourceLanguage = lang
                }
                return .none

            case .bottomLanguageChanged(let lang):
                state.bottomLanguage = lang
                state.speechRecognition.recognizedText = ""
                state.translation.translatedText = ""
                if state.activeMic == .bottom {
                    state.speechRecognition.sourceLanguage = lang
                } else {
                    state.translation.targetLanguage = lang
                }
                return .none

            case .swapLanguagesTapped:
                let tmp = state.topLanguage
                state.topLanguage = state.bottomLanguage
                state.bottomLanguage = tmp
                state.speechRecognition.recognizedText = ""
                state.translation.translatedText = ""
                if state.activeMic == .bottom {
                    state.speechRecognition.sourceLanguage = state.bottomLanguage
                    state.translation.targetLanguage = state.topLanguage
                } else {
                    state.speechRecognition.sourceLanguage = state.topLanguage
                    state.translation.targetLanguage = state.bottomLanguage
                }
                return .none

            // MARK: - UI 상태

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

            case .appLanguageChanged(let lang):
                state.appLanguage = lang
                UserDefaults.standard.set(lang, forKey: "appLanguage")
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

            case .expandTopPanel:
                state.isTopExpanded = true
                return .none

            case .collapseTopPanel:
                state.isTopExpanded = false
                return .none

            case .expandBottomPanel:
                state.isBottomExpanded = true
                return .none

            case .collapseBottomPanel:
                state.isBottomExpanded = false
                return .none

            // MARK: - 자동 TTS / 번역 연결

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
