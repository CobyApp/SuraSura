import SwiftUI
import ComposableArchitecture

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeReducer>

    public init(store: StoreOf<HomeReducer>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // 헤더
                Text("すらすら")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                // 언어 선택
                LanguageSelectorView(store: store)

                Spacer()

                // 음성 인식 결과
                TranscriptionCardView(
                    title: "인식 중",
                    text: store.speechRecognition.recognizedText,
                    isActive: store.speechRecognition.isListening
                )

                // 번역 결과 + 스피커 버튼
                TranscriptionCardView(
                    title: "번역",
                    text: store.translation.translatedText,
                    isActive: store.translation.isSpeaking,
                    onSpeakTapped: {
                        if store.translation.isSpeaking {
                            store.send(.translation(.stopSpeaking))
                        } else {
                            store.send(.translation(.speakRequested))
                        }
                    }
                )

                Spacer()

                // 녹음 버튼
                RecordButton(isActive: store.isSessionActive) {
                    if store.isSessionActive {
                        store.send(.stopSessionTapped)
                    } else {
                        store.send(.startSessionTapped)
                    }
                }
            }
            .padding(24)
        }
    }
}
