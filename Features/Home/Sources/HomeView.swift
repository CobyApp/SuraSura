import SwiftUI
import ComposableArchitecture
import APIClient

private let kBlue = Color(red: 0.11, green: 0.53, blue: 0.87)

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeReducer>

    public init(store: StoreOf<HomeReducer>) { self.store = store }

    private var settingsBinding: Binding<Bool> {
        Binding(get: { store.isSettingsPresented },
                set: { if !$0 { store.send(.settingsDismissed) } })
    }

    public var body: some View {
        ZStack {
            // ① 배경: safe area 포함 전체 채움 (Dynamic Island 뒤까지)
            VStack(spacing: 0) {
                kBlue.frame(maxWidth: .infinity, maxHeight: .infinity)
                Color(.systemBackground).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()

            // ② 콘텐츠: safe area 자연 존중 → Dynamic Island/홈인디케이터 침범 없음
            VStack(spacing: 0) {
                translationPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // 대면모드: 패널 전체(피커 포함)가 함께 뒤집힘 → Dynamic Island 방향도 safe
                    .rotationEffect(store.isFaceToFaceMode ? .degrees(180) : .zero)
                    .animation(.spring(response: 0.45, dampingFraction: 0.82),
                               value: store.isFaceToFaceMode)

                recognitionPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(store.appColorScheme.swiftUIColorScheme)
        .sheet(isPresented: settingsBinding) {
            SettingsView(store: store).presentationDetents([.medium])
        }
    }

    // MARK: - 번역 패널 (상단 / 뒤집힘)

    private var translationPanel: some View {
        ZStack {
            if store.isTopPickerPresented {
                // 피커가 패널 내부에 있으므로 대면모드 시 함께 180° 회전 ✓
                LanguagePickerOverlay(
                    selected: store.translation.targetLanguage,
                    bgColor: kBlue,
                    rowFg: .white,
                    accentColor: .white,
                    onSelect: { store.send(.translation(.languageChanged($0))) },
                    onDismiss: { store.send(.hideTopPicker) }
                )
            } else {
                translationContent
            }
        }
    }

    private var translationContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 텍스트 탭 → TTS 재생/중지
            translationTextArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            translationBottomRow
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 28)
    }

    private var translationTextArea: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.vertical, showsIndicators: false) {
                Text(store.translation.translatedText.isEmpty
                     ? "　" : store.translation.translatedText)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(8)
                    .animation(.easeInOut(duration: 0.15),
                               value: store.translation.translatedText)
            }
            .contentShape(Rectangle())
            .onTapGesture { store.send(.translationTextTapped) }

            // TTS 재생 중 표시 (버튼 없이 뱃지로)
            if store.translation.isSpeaking {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(6)
            }
        }
    }

    private var translationBottomRow: some View {
        HStack(spacing: 0) {
            // 언어 스왑 버튼 (대면모드에서도 피커 사용자가 접근 가능)
            circleBtn(icon: "arrow.left.arrow.right", fg: .white.opacity(0.85),
                      bg: .white.opacity(0.18)) {
                store.send(.swapLanguagesTapped)
            }

            Spacer()

            // 번역 언어 피커
            panelLangButton(
                language: store.translation.targetLanguage,
                fg: .white
            ) { store.send(.showTopPicker) }
        }
    }

    // MARK: - 인식 패널 (하단 / 고정)

    private var recognitionPanel: some View {
        ZStack {
            if store.isBottomPickerPresented {
                LanguagePickerOverlay(
                    selected: store.speechRecognition.sourceLanguage,
                    bgColor: Color(.systemBackground),
                    rowFg: .primary,
                    accentColor: kBlue,
                    onSelect: { store.send(.speechRecognition(.languageChanged($0))) },
                    onDismiss: { store.send(.hideBottomPicker) }
                )
            } else {
                recognitionContent
            }
        }
    }

    private var recognitionContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            recognitionTextArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            recognitionBottomRow
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .safeAreaPadding(.bottom)   // 홈인디케이터 여백 자동 확보
    }

    private var recognitionTextArea: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(store.speechRecognition.recognizedText.isEmpty
                 ? "　" : store.speechRecognition.recognizedText)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(8)
                .animation(.easeInOut(duration: 0.15),
                           value: store.speechRecognition.recognizedText)
        }
    }

    private var recognitionBottomRow: some View {
        HStack(spacing: 12) {
            // 설정
            circleBtn(icon: "gearshape", fg: Color.secondary,
                      bg: Color(.secondarySystemFill)) {
                store.send(.settingsTapped)
            }
            // 대면 모드
            circleBtn(
                icon: store.isFaceToFaceMode ? "person.2.fill" : "person.2",
                fg: store.isFaceToFaceMode ? kBlue : Color.secondary,
                bg: store.isFaceToFaceMode ? kBlue.opacity(0.12) : Color(.secondarySystemFill)
            ) { store.send(.toggleFaceToFaceTapped) }

            Spacer()

            // 인식 언어 피커
            panelLangButton(
                language: store.speechRecognition.sourceLanguage,
                fg: .primary
            ) { store.send(.showBottomPicker) }

            // 녹음/중지 버튼
            micStopButton
        }
    }

    // MARK: - 녹음/중지 버튼

    private var micStopButton: some View {
        Button {
            store.send(store.isSessionActive ? .stopSessionTapped : .startSessionTapped)
        } label: {
            ZStack {
                // 펄스 링 (녹음 중)
                if store.isSessionActive {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2.5)
                        .frame(width: 76, height: 76)
                }
                Image(systemName: store.isSessionActive ? "stop.fill" : "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 62, height: 62)
                    .background(store.isSessionActive ? Color.red : kBlue, in: Circle())
                    .shadow(
                        color: store.isSessionActive
                            ? .red.opacity(0.4) : kBlue.opacity(0.4),
                        radius: 10, y: 4
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 공용 헬퍼

    private func circleBtn(
        icon: String, fg: Color, bg: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: 40, height: 40)
                .background(bg, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func panelLangButton(
        language: SupportedLanguage, fg: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(language.flag).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 1) {
                    Text(language.shortName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(fg)
                    Text(language.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(fg.opacity(0.55))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(fg.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
}
