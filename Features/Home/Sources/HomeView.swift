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
            // 배경: Dynamic Island 포함 전체 채움
            VStack(spacing: 0) {
                kBlue.frame(maxWidth: .infinity, maxHeight: .infinity)
                Color(.systemBackground).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()

            // 콘텐츠: safe area 자연 존중
            VStack(spacing: 0) {
                translationPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - 번역 패널

    private var translationPanel: some View {
        ZStack {
            if store.isTopPickerPresented {
                LanguagePickerOverlay(
                    selected: store.translation.targetLanguage,
                    bgColor: kBlue, rowFg: .white, accentColor: .white,
                    onSelect: { store.send(.translation(.languageChanged($0))) },
                    onDismiss: { store.send(.hideTopPicker) }
                )
            } else {
                translationContent
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.isTopPickerPresented)
    }

    private var translationContent: some View {
        // ScrollView + 컨트롤을 overlay로 분리 → ScrollView 제스처 간섭 없음
        ScrollView(.vertical, showsIndicators: false) {
            translationText
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 104) // 하단 컨트롤 영역 확보
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { store.send(.translationTextTapped) }
        .overlay(alignment: .topTrailing) {
            // TTS 재생 중 뱃지
            if store.translation.isSpeaking {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(12)
            }
        }
        .overlay(alignment: .bottom) {
            translationBottomRow
        }
    }

    private var translationText: some View {
        Text(store.translation.translatedText.isEmpty
             ? "　" : store.translation.translatedText)
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(8)
            .animation(.easeInOut(duration: 0.15), value: store.translation.translatedText)
    }

    private var translationBottomRow: some View {
        HStack(spacing: 0) {
            circleBtn(icon: "arrow.left.arrow.right",
                      fg: .white.opacity(0.85), bg: .white.opacity(0.18)) {
                store.send(.swapLanguagesTapped)
            }
            Spacer()
            panelLangButton(language: store.translation.targetLanguage, fg: .white) {
                store.send(.showTopPicker)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .padding(.top, 24)
        .background(
            LinearGradient(colors: [kBlue.opacity(0), kBlue, kBlue],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - 인식 패널

    private var recognitionPanel: some View {
        ZStack {
            if store.isBottomPickerPresented {
                LanguagePickerOverlay(
                    selected: store.speechRecognition.sourceLanguage,
                    bgColor: Color(.systemBackground), rowFg: .primary, accentColor: kBlue,
                    onSelect: { store.send(.speechRecognition(.languageChanged($0))) },
                    onDismiss: { store.send(.hideBottomPicker) }
                )
            } else {
                recognitionContent
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.isBottomPickerPresented)
    }

    private var recognitionContent: some View {
        // 컨트롤을 overlay로 배치 → ScrollView가 버튼 탭 절대 흡수 안 함 ✓
        ScrollView(.vertical, showsIndicators: false) {
            recognitionText
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 112) // 하단 컨트롤 영역 확보
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            recognitionBottomRow
        }
    }

    private var recognitionText: some View {
        Text(store.speechRecognition.recognizedText.isEmpty
             ? "　" : store.speechRecognition.recognizedText)
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(8)
            .animation(.easeInOut(duration: 0.15), value: store.speechRecognition.recognizedText)
    }

    private var recognitionBottomRow: some View {
        HStack(spacing: 12) {
            circleBtn(icon: "gearshape", fg: Color.secondary,
                      bg: Color(.secondarySystemFill)) {
                store.send(.settingsTapped)
            }
            circleBtn(
                icon: store.isFaceToFaceMode ? "person.2.fill" : "person.2",
                fg: store.isFaceToFaceMode ? kBlue : Color.secondary,
                bg: store.isFaceToFaceMode ? kBlue.opacity(0.12) : Color(.secondarySystemFill)
            ) { store.send(.toggleFaceToFaceTapped) }

            Spacer()

            panelLangButton(language: store.speechRecognition.sourceLanguage, fg: .primary) {
                store.send(.showBottomPicker)
            }

            // 녹음/중지 버튼 (고정 76×76 프레임 — 절대 레이아웃 안 밀림)
            MicButton(isActive: store.isSessionActive, color: kBlue) {
                store.send(store.isSessionActive ? .stopSessionTapped : .startSessionTapped)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
        .padding(.top, 24)
        .safeAreaPadding(.bottom)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0),
                         Color(.systemBackground), Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
        )
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
                Text(language.flag).font(.system(size: 24))
                Text(language.localizedName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(fg)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(fg.opacity(0.5))
            }
            // 최소 너비 고정 → 언어 전환 시 레이아웃 흔들림 방지
            .frame(minWidth: 110, alignment: .trailing)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 녹음/중지 버튼 (독립 뷰 — 고정 프레임 + 펄스 애니메이션)

private struct MicButton: View {
    let isActive: Bool
    let color: Color
    let action: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // 펄스 링: 항상 레이아웃에 존재 (opacity로 표시/숨김) → 크기 변화 없음 ✓
                Circle()
                    .stroke(Color.red.opacity(0.35), lineWidth: 2.5)
                    .frame(width: 76, height: 76)
                    .scaleEffect(pulsing ? 1.22 : 1.0)
                    .opacity(isActive ? 1 : 0)

                // 메인 버튼
                Image(systemName: isActive ? "stop.fill" : "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 62, height: 62)
                    .background(isActive ? Color.red : color, in: Circle())
                    .shadow(
                        color: isActive ? .red.opacity(0.4) : color.opacity(0.4),
                        radius: 10, y: 4
                    )
                    .animation(.easeInOut(duration: 0.15), value: isActive)
            }
            .frame(width: 76, height: 76) // ← 고정 크기, 절대 밀리지 않음
        }
        .buttonStyle(.plain)
        .onAppear { if isActive { startPulse() } }
        .onChange(of: isActive) { _, active in
            active ? startPulse() : stopPulse()
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }
    private func stopPulse() {
        withAnimation(.easeInOut(duration: 0.2)) {
            pulsing = false
        }
    }
}
