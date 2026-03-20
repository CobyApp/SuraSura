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

    private var appBundle: Bundle {
        Bundle.localizedModule(language: store.appLanguage)
    }

    public var body: some View {
        ZStack {
            // 배경: GeometryReader와 동일한 safe area 기준으로 절반 분할
            // → kBlue는 Dynamic Island 위로 확장, 흰색은 홈 인디케이터 아래로 확장
            // → 배경 경계선 = 콘텐츠 경계선 (safe area 기준 정확히 일치)
            VStack(spacing: 0) {
                kBlue
                    .ignoresSafeArea(edges: .top)
                    .frame(maxHeight: .infinity)
                Color(.systemBackground)
                    .ignoresSafeArea(edges: .bottom)
                    .frame(maxHeight: .infinity)
            }

            // 콘텐츠 — GeometryReader로 패널 높이 1:1 픽셀 고정
            GeometryReader { geo in
                VStack(spacing: 0) {
                    translationPanel
                        .frame(width: geo.size.width, height: geo.size.height / 2)
                    recognitionPanel
                        .frame(width: geo.size.width, height: geo.size.height / 2)
                }
            }
        }
        .preferredColorScheme(store.appColorScheme.swiftUIColorScheme)
        .sheet(isPresented: settingsBinding) {
            SettingsView(store: store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
        }
        // 번역 텍스트 전체화면
        .fullScreenCover(isPresented: Binding(
            get: { store.isTopExpanded },
            set: { if !$0 { store.send(.collapseTopPanel) } }
        )) {
            ExpandedTextView(
                text: store.translation.translatedText,
                bgColor: kBlue, fgColor: .white,
                isSpeaking: store.translation.isSpeaking,
                onClose: { store.send(.collapseTopPanel) },
                onSpeak: { store.send(.translationTextTapped) }
            )
            .preferredColorScheme(store.appColorScheme.swiftUIColorScheme)
        }
        // 인식 텍스트 전체화면
        .fullScreenCover(isPresented: Binding(
            get: { store.isBottomExpanded },
            set: { if !$0 { store.send(.collapseBottomPanel) } }
        )) {
            ExpandedTextView(
                text: store.speechRecognition.recognizedText,
                bgColor: Color(.systemBackground), fgColor: .primary,
                isSpeaking: false,
                onClose: { store.send(.collapseBottomPanel) },
                onSpeak: nil
            )
            .preferredColorScheme(store.appColorScheme.swiftUIColorScheme)
        }
    }

    // MARK: - 번역 패널

    private var translationPanel: some View {
        ZStack {
            if store.isTopPickerPresented {
                LanguagePickerOverlay(
                    selected: store.translation.targetLanguage,
                    bgColor: kBlue, rowFg: .white, accentColor: .white,
                    bundle: appBundle,
                    onSelect: { store.send(.translation(.languageChanged($0))) },
                    onDismiss: { store.send(.hideTopPicker) }
                )
                .scaleEffect(x: store.isFaceToFaceMode ? -1 : 1,
                             y: store.isFaceToFaceMode ? -1 : 1)
                .animation(.easeInOut(duration: 0.35), value: store.isFaceToFaceMode)
            } else {
                // 단일 인스턴스 — 레이아웃 높이 불변, 부드러운 fold 전환
                translationContent
                    .scaleEffect(x: store.isFaceToFaceMode ? -1 : 1,
                                 y: store.isFaceToFaceMode ? -1 : 1)
                    .animation(.easeInOut(duration: 0.35), value: store.isFaceToFaceMode)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.isTopPickerPresented)
    }

    private var translationContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            translationText
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 130)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { store.send(.translationTextTapped) }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                // TTS 재생 중 표시
                if store.translation.isSpeaking {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.trailing, 4)
                }
                // 확장 버튼 (텍스트 있을 때만)
                if !store.translation.translatedText.isEmpty {
                    Button { store.send(.expandTopPanel) } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .padding(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(alignment: .bottom) {
            translationBottomRow
        }
    }

    private var translationText: some View {
        Text(store.translation.translatedText.isEmpty
             ? "　" : store.translation.translatedText)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(6)
            .animation(.easeInOut(duration: 0.15), value: store.translation.translatedText)
    }

    private var translationBottomRow: some View {
        HStack(spacing: 10) {
            Spacer()
            panelLangButton(language: store.translation.targetLanguage, fg: .white) {
                store.send(.showTopPicker)
            }
            // 상단 녹음 버튼 — 언어선택 오른쪽 (하단과 동일 레이아웃)
            MicButton(isActive: store.isSessionActive, color: Color.white.opacity(0.3)) {
                store.send(store.isSessionActive ? .stopSessionTapped : .startTopSessionTapped)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 20)
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
                    bundle: appBundle,
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
        ScrollView(.vertical, showsIndicators: false) {
            recognitionText
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 112)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            // 확장 버튼 (텍스트 있을 때만)
            if !store.speechRecognition.recognizedText.isEmpty {
                Button { store.send(.expandBottomPanel) } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                        .padding(12)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            recognitionBottomRow
        }
    }

    private var recognitionText: some View {
        Text(store.speechRecognition.recognizedText.isEmpty
             ? "　" : store.speechRecognition.recognizedText)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(6)
            .animation(.easeInOut(duration: 0.15), value: store.speechRecognition.recognizedText)
    }

    private var recognitionBottomRow: some View {
        HStack(spacing: 10) {
            // 설정
            circleBtn(icon: "gearshape",
                      fg: Color.secondary,
                      bg: Color(.secondarySystemFill)) {
                store.send(.settingsTapped)
            }
            // 대면 모드
            circleBtn(
                icon: store.isFaceToFaceMode ? "person.2.fill" : "person.2",
                fg: store.isFaceToFaceMode ? kBlue : Color.secondary,
                bg: store.isFaceToFaceMode ? kBlue.opacity(0.12) : Color(.secondarySystemFill)
            ) { store.send(.toggleFaceToFaceTapped) }

            // 언어 전환 화살표 (하단 그룹으로 이동)
            circleBtn(icon: "arrow.left.arrow.right",
                      fg: Color.secondary,
                      bg: Color(.secondarySystemFill)) {
                store.send(.swapLanguagesTapped)
            }

            Spacer()

            // 언어 선택
            panelLangButton(language: store.speechRecognition.sourceLanguage, fg: .primary) {
                store.send(.showBottomPicker)
            }

            // 녹음/중지 버튼
            MicButton(isActive: store.isSessionActive, color: kBlue) {
                store.send(store.isSessionActive ? .stopSessionTapped : .startSessionTapped)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 20)
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
            .frame(minWidth: 110, alignment: .trailing)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 녹음/중지 버튼

private struct MicButton: View {
    let isActive: Bool
    let color: Color
    let action: () -> Void

    @State private var pulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.35), lineWidth: 2.5)
                    .frame(width: 76, height: 76)
                    .scaleEffect(pulsing ? 1.22 : 1.0)
                    .opacity(isActive ? 1 : 0)

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
            .frame(width: 76, height: 76)
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
        withAnimation(.easeInOut(duration: 0.2)) { pulsing = false }
    }
}

// MARK: - 텍스트 전체화면 확장 뷰

private struct ExpandedTextView: View {
    let text: String
    let bgColor: Color
    let fgColor: Color
    let isSpeaking: Bool
    let onClose: () -> Void
    let onSpeak: (() -> Void)?

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 버튼 바
                HStack {
                    Spacer()
                    if let onSpeak {
                        Button(action: onSpeak) {
                            Image(systemName: isSpeaking
                                  ? "speaker.wave.2.fill" : "speaker.wave.2")
                                .font(.system(size: 20))
                                .foregroundStyle(fgColor.opacity(0.7))
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 30))
                            .foregroundStyle(fgColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // 텍스트 스크롤 영역
                ScrollView(.vertical, showsIndicators: false) {
                    Text(text.isEmpty ? "　" : text)
                        .font(.system(size: 34, weight: .regular))
                        .foregroundStyle(fgColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(10)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 28)
                }
            }
        }
    }
}
