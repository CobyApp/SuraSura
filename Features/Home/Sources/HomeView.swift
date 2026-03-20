import SwiftUI
import ComposableArchitecture

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeReducer>

    public init(store: StoreOf<HomeReducer>) {
        self.store = store
    }

    private var settingsBinding: Binding<Bool> {
        Binding(
            get: { store.isSettingsPresented },
            set: { if !$0 { store.send(.settingsDismissed) } }
        )
    }

    public var body: some View {
        ZStack {
            // 배경: 안전영역 밖까지 확장
            backgroundGradient
                .ignoresSafeArea()

            // 콘텐츠: safe area 자연 존중
            VStack(spacing: 0) {
                translationPanel
                divider
                controlBar
                divider
                recognitionPanel
            }
        }
        .preferredColorScheme(store.appColorScheme.swiftUIColorScheme)
        .sheet(isPresented: settingsBinding) {
            SettingsView(store: store)
                .presentationDetents([.medium])
        }
    }

    // MARK: - 배경

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - 구분선

    private var divider: some View {
        Divider()
            .padding(.horizontal, 20)
    }

    // MARK: - 상단 번역 패널

    private var translationPanel: some View {
        TranscriptionCardView(
            title: String(localized: "panel.translation", bundle: .module),
            text: store.translation.translatedText,
            isActive: store.translation.isSpeaking,
            isFlipped: store.isFaceToFaceMode,
            onSpeakTapped: {
                if store.translation.isSpeaking {
                    store.send(.translation(.stopSpeaking))
                } else {
                    store.send(.translation(.speakRequested))
                }
            }
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 중앙 컨트롤 바

    private var controlBar: some View {
        VStack(spacing: 14) {
            LanguageSelectorView(store: store)
            actionButtons
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var actionButtons: some View {
        HStack {
            // 설정 버튼
            circleButton(icon: "gearshape.fill", tint: .secondary) {
                store.send(.settingsTapped)
            }

            Spacer()

            // 녹음 버튼 (중앙, 가장 크게)
            RecordButton(isActive: store.isSessionActive) {
                store.send(store.isSessionActive ? .stopSessionTapped : .startSessionTapped)
            }

            Spacer()

            // 대면 모드 버튼
            circleButton(
                icon: store.isFaceToFaceMode ? "person.2.fill" : "person.2",
                tint: store.isFaceToFaceMode ? .accentColor : .secondary,
                isActive: store.isFaceToFaceMode
            ) {
                store.send(.toggleFaceToFaceTapped)
            }
        }
    }

    @ViewBuilder
    private func circleButton(
        icon: String,
        tint: Color,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(
                    isActive
                        ? tint.opacity(0.15)
                        : Color(.tertiarySystemFill),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 하단 인식 패널

    private var recognitionPanel: some View {
        TranscriptionCardView(
            title: String(localized: "panel.listening", bundle: .module),
            text: store.speechRecognition.recognizedText,
            isActive: store.speechRecognition.isListening
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
