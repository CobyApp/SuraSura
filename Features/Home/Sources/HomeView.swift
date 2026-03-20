import SwiftUI
import ComposableArchitecture

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeReducer>

    public init(store: StoreOf<HomeReducer>) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // 배경
                backgroundGradient

                VStack(spacing: 0) {
                    // ── 상단 패널: 번역 결과 (대면모드시 뒤집힘) ──
                    translationPanel(geo: geo)

                    // ── 중앙 컨트롤 바 ──
                    controlBar

                    // ── 하단 패널: 음성 인식 ──
                    recognitionPanel(geo: geo)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(store.appColorScheme.swiftUIColorScheme)
        .sheet(isPresented: $store.isSettingsPresented) {
            SettingsView(store: store)
                .presentationDetents([.medium])
        }
    }

    // MARK: - 배경

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - 상단 패널 (번역 결과)

    private func translationPanel(geo: GeometryProxy) -> some View {
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
        .frame(height: geo.size.height * 0.40)
        .padding(.horizontal, 16)
        .padding(.top, geo.safeAreaInsets.top + 8)
    }

    // MARK: - 중앙 컨트롤 바

    private var controlBar: some View {
        VStack(spacing: 12) {
            // 언어 선택 + 스왑
            LanguageSelectorView(store: store)

            // 버튼 행: 설정 | 녹음 | 대면모드
            HStack(spacing: 0) {
                // 설정 버튼
                Button {
                    store.send(.settingsTapped)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                // 녹음 버튼 (중앙)
                RecordButton(isActive: store.isSessionActive) {
                    if store.isSessionActive {
                        store.send(.stopSessionTapped)
                    } else {
                        store.send(.startSessionTapped)
                    }
                }

                Spacer()

                // 대면 모드 버튼
                Button {
                    store.send(.toggleFaceToFaceTapped)
                } label: {
                    Image(systemName: store.isFaceToFaceMode
                          ? "person.2.fill"
                          : "person.2")
                        .font(.system(size: 18))
                        .foregroundStyle(store.isFaceToFaceMode ? .accent : .secondary)
                        .frame(width: 52, height: 52)
                        .background(
                            store.isFaceToFaceMode
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear,
                            in: Circle()
                        )
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 16)
        .background(.bar)
    }

    // MARK: - 하단 패널 (음성 인식)

    private func recognitionPanel(geo: GeometryProxy) -> some View {
        TranscriptionCardView(
            title: String(localized: "panel.listening", bundle: .module),
            text: store.speechRecognition.recognizedText,
            isActive: store.speechRecognition.isListening
        )
        .frame(height: geo.size.height * 0.40)
        .padding(.horizontal, 16)
        .padding(.bottom, geo.safeAreaInsets.bottom + 8)
    }
}
