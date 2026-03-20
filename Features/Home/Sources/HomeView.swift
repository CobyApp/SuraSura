import SwiftUI
import ComposableArchitecture
import APIClient

// 앱 전체 테마 컬러
private let kTopColor = Color(red: 0.11, green: 0.53, blue: 0.87)

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
        VStack(spacing: 0) {
            // ── 상단 패널: 번역 결과 (대면 모드 시 180° 플립) ──
            translationPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .rotationEffect(store.isFaceToFaceMode ? .degrees(180) : .zero)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: store.isFaceToFaceMode)

            // ── 하단 패널: 음성 인식 ──
            recognitionPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .preferredColorScheme(store.appColorScheme.swiftUIColorScheme)
        .sheet(isPresented: settingsBinding) {
            SettingsView(store: store)
                .presentationDetents([.medium])
        }
    }

    // MARK: - 상단 번역 패널

    private var translationPanel: some View {
        ZStack {
            kTopColor // 파란 배경이 상태바 뒤까지 채움

            VStack(alignment: .leading, spacing: 0) {
                // 번역 텍스트 (상단 여백 = 상태바 높이 확보)
                ScrollView(.vertical, showsIndicators: false) {
                    Text(store.translation.translatedText.isEmpty
                         ? "　" : store.translation.translatedText)
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(8)
                        .animation(.easeInOut(duration: 0.15), value: store.translation.translatedText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 하단 컨트롤 행
                HStack(alignment: .center, spacing: 0) {
                    // 언어 스왑 버튼
                    Button { store.send(.swapLanguagesTapped) } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.18), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // 언어 선택 (번역 언어)
                    panelLanguagePicker(
                        language: store.translation.targetLanguage,
                        textColor: .white
                    ) { store.send(.translation(.languageChanged($0))) }

                    Spacer(minLength: 20)

                    // TTS(스피커) 버튼
                    Button {
                        store.send(store.translation.isSpeaking
                            ? .translation(.stopSpeaking)
                            : .translation(.speakRequested))
                    } label: {
                        Image(systemName: store.translation.isSpeaking
                              ? "speaker.wave.3.fill" : "speaker.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(kTopColor)
                            .frame(width: 62, height: 62)
                            .background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
            .safeAreaPadding(.top)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - 하단 인식 패널

    private var recognitionPanel: some View {
        ZStack {
            Color(.systemBackground) // 다크/라이트 자동 대응

            VStack(alignment: .leading, spacing: 0) {
                // 인식된 텍스트
                ScrollView(.vertical, showsIndicators: false) {
                    Text(store.speechRecognition.recognizedText.isEmpty
                         ? "　" : store.speechRecognition.recognizedText)
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(8)
                        .animation(.easeInOut(duration: 0.15), value: store.speechRecognition.recognizedText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 하단 컨트롤 행
                HStack(alignment: .center, spacing: 0) {
                    // 설정 버튼
                    Button { store.send(.settingsTapped) } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color(.secondarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)

                    // 대면 모드 토글
                    Button { store.send(.toggleFaceToFaceTapped) } label: {
                        Image(systemName: store.isFaceToFaceMode ? "person.2.fill" : "person.2")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(store.isFaceToFaceMode ? kTopColor : Color.secondary)
                            .frame(width: 40, height: 40)
                            .background(
                                store.isFaceToFaceMode
                                    ? kTopColor.opacity(0.12)
                                    : Color(.secondarySystemFill),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 10)

                    Spacer()

                    // 언어 선택 (인식 언어)
                    panelLanguagePicker(
                        language: store.speechRecognition.sourceLanguage,
                        textColor: .primary
                    ) { store.send(.speechRecognition(.languageChanged($0))) }

                    Spacer(minLength: 20)

                    // 녹음 버튼
                    micButton
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 16)
            .safeAreaPadding(.bottom)
        }
    }

    // MARK: - 녹음 버튼

    private var micButton: some View {
        Button {
            store.send(store.isSessionActive ? .stopSessionTapped : .startSessionTapped)
        } label: {
            ZStack {
                if store.isSessionActive {
                    Circle()
                        .stroke(Color.red.opacity(0.35), lineWidth: 2.5)
                        .frame(width: 78, height: 78)
                }
                Image(systemName: store.isSessionActive ? "stop.fill" : "mic.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(
                        store.isSessionActive ? Color.red : kTopColor,
                        in: Circle()
                    )
                    .shadow(
                        color: store.isSessionActive
                            ? .red.opacity(0.4) : kTopColor.opacity(0.4),
                        radius: 10, y: 4
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 공용 언어 피커

    private func panelLanguagePicker(
        language: SupportedLanguage,
        textColor: Color,
        onSelect: @escaping (SupportedLanguage) -> Void
    ) -> some View {
        Menu {
            ForEach(SupportedLanguage.allCases, id: \.self) { lang in
                Button(lang.displayName) { onSelect(lang) }
            }
        } label: {
            HStack(spacing: 8) {
                Text(language.flag)
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 1) {
                    Text(language.shortName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(textColor)
                    Text(language.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(textColor.opacity(0.6))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(textColor.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }
}
