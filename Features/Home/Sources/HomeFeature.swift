import Foundation
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
        public var isAutoSpeakEnabled: Bool = true
        // 커스텀 언어 피커
        public var isTopPickerPresented: Bool = false
        public var isBottomPickerPresented: Bool = false
        // 앱 내 언어 설정 ("" = 시스템 기본값)
        public var appLanguage: String = ""
        // 텍스트 전체화면 확장
        public var isTopExpanded: Bool = false
        public var isBottomExpanded: Bool = false
        // 상단 마이크로 세션 시작 시 언어가 임시 스왑된 상태인지 추적
        public var swappedForTopSession: Bool = false
        // 상단 마이크 활성 중: 상단=인식텍스트, 하단=번역결과 로 표시
        public var isTopMicActive: Bool = false

        public init() {
            self.appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        }
    }

    public enum Action {
        case speechRecognition(SpeechRecognitionReducer.Action)
        case translation(TranslationReducer.Action)
        case startSessionTapped
        case stopSessionTapped
        case startTopSessionTapped  // 상단 패널 마이크 — 언어 방향 반전 후 녹음 시작
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
            case .startSessionTapped:
                state.isSessionActive = true
                return .send(.speechRecognition(.startListening))

            case .stopSessionTapped:
                state.isSessionActive = false
                if state.swappedForTopSession {
                    state.swappedForTopSession = false
                    state.isTopMicActive = false
                    let src = state.speechRecognition.sourceLanguage
                    let tgt = state.translation.targetLanguage
                    return .run { send in
                        await send(.speechRecognition(.stopListening))
                        await send(.speechRecognition(.languageChanged(tgt)))
                        await send(.translation(.languageChanged(src)))
                    }
                }
                return .send(.speechRecognition(.stopListening))

            case .startTopSessionTapped:
                guard !state.isSessionActive else { return .none }
                state.isSessionActive = true
                state.swappedForTopSession = true
                state.isTopMicActive = true
                let src = state.speechRecognition.sourceLanguage
                let tgt = state.translation.targetLanguage
                return .run { send in
                    await send(.speechRecognition(.languageChanged(tgt)))
                    await send(.translation(.languageChanged(src)))
                    await send(.speechRecognition(.startListening))
                }

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
