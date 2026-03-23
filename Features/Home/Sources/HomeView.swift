import SwiftUI
import ComposableArchitecture
import APIClient
import DesignSystem

// DesignTokens.accentBlue 를 짧게 참조하기 위한 파일 스코프 별칭
private let kBlue = DesignTokens.accentBlue

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

    private func l(_ key: String) -> String {
        appBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    public var body: some View {
        ZStack {
            // 배경: 상단 파랑 / 하단 흰색
            VStack(spacing: 0) {
                kBlue
                    .ignoresSafeArea(edges: .top)
                    .frame(maxHeight: .infinity)
                Color(.systemBackground)
                    .ignoresSafeArea(edges: .bottom)
                    .frame(maxHeight: .infinity)
            }

            // 콘텐츠
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
        // 번역 텍스트 전체화면 (대면 모드면 뒤집힘 유지)
        .fullScreenCover(isPresented: Binding(
            get: { store.isTopExpanded },
            set: { if !$0 { store.send(.collapseTopPanel) } }
        )) {
            ExpandedTextView(
                text: store.activeMic == .top
                    ? store.speechRecognition.recognizedText
                    : store.translation.translatedText,
                bgColor: kBlue, fgColor: .white,
                isFaceToFace: store.isFaceToFaceMode,
                onClose: { store.send(.collapseTopPanel) }
            )
            .preferredColorScheme(store.appColorScheme.swiftUIColorScheme)
        }
        // 인식 텍스트 전체화면
        .fullScreenCover(isPresented: Binding(
            get: { store.isBottomExpanded },
            set: { if !$0 { store.send(.collapseBottomPanel) } }
        )) {
            ExpandedTextView(
                text: store.activeMic == .top
                    ? store.translation.translatedText
                    : store.speechRecognition.recognizedText,
                bgColor: Color(.systemBackground), fgColor: .primary,
                isFaceToFace: false,
                onClose: { store.send(.collapseBottomPanel) }
            )
            .preferredColorScheme(store.appColorScheme.swiftUIColorScheme)
        }
    }

    // MARK: - 번역 패널 (상단)

    private var translationPanel: some View {
        ZStack {
            if store.isTopPickerPresented {
                LanguagePickerOverlay(
                    selected: store.topLanguage,
                    bgColor: kBlue, rowFg: .white, accentColor: .white,
                    bundle: appBundle,
                    appLanguage: store.appLanguage,
                    onSelect: { store.send(.topLanguageChanged($0)) },
                    onDismiss: { store.send(.hideTopPicker) }
                )
                .scaleEffect(x: store.isFaceToFaceMode ? -1 : 1,
                             y: store.isFaceToFaceMode ? -1 : 1)
                .animation(.easeInOut(duration: 0.35), value: store.isFaceToFaceMode)
            } else {
                translationContent
                    .scaleEffect(x: store.isFaceToFaceMode ? -1 : 1,
                                 y: store.isFaceToFaceMode ? -1 : 1)
                    .animation(.easeInOut(duration: 0.35), value: store.isFaceToFaceMode)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.isTopPickerPresented)
    }

    private var translationContent: some View {
        // 상단 마이크 활성: 상단=말한내용, 하단=번역결과
        let displayText = store.activeMic == .top
            ? store.speechRecognition.recognizedText
            : store.translation.translatedText
        return ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // 플레이스홀더
                if displayText.isEmpty {
                    Text(l("panel.mic_hint"))
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                }
                Text(displayText.isEmpty ? "　" : displayText)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(6)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 130)
                    .animation(.easeInOut(duration: 0.15), value: displayText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            expandButton(isEmpty: displayText.isEmpty, fg: .white) {
                store.send(.expandTopPanel)
            }
        }
        .overlay(alignment: .bottom) {
            translationBottomRow
        }
    }

    private var translationBottomRow: some View {
        HStack(spacing: 10) {
            Spacer()
            panelLangButton(language: store.topLanguage, fg: .white) {
                store.send(.showTopPicker)
            }
            MicButton(isActive: store.isSessionActive && store.activeMic == .top,
                      color: Color.white.opacity(0.3)) {
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

    // MARK: - 인식/입력 패널 (하단)

    private var recognitionPanel: some View {
        ZStack {
            if store.isBottomPickerPresented {
                LanguagePickerOverlay(
                    selected: store.bottomLanguage,
                    bgColor: Color(.systemBackground), rowFg: .primary, accentColor: kBlue,
                    bundle: appBundle,
                    appLanguage: store.appLanguage,
                    onSelect: { store.send(.bottomLanguageChanged($0)) },
                    onDismiss: { store.send(.hideBottomPicker) }
                )
            } else {
                recognitionContent
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.isBottomPickerPresented)
    }

    private var recognitionContent: some View {
        let displayText = store.activeMic == .top
            ? store.translation.translatedText
            : store.speechRecognition.recognizedText
        return recognitionText
            .overlay(alignment: .topTrailing) {
                expandButton(isEmpty: displayText.isEmpty, fg: Color.secondary) {
                    store.send(.expandBottomPanel)
                }
            }
            .overlay(alignment: .bottom) {
                recognitionBottomRow(displayText: displayText)
            }
    }

    private var recognitionText: some View {
        let displayText = store.activeMic == .top
            ? store.translation.translatedText
            : store.speechRecognition.recognizedText
        return ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                if displayText.isEmpty {
                    Text(l("panel.mic_hint"))
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                }
                Text(displayText.isEmpty ? "　" : displayText)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(5)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                    .animation(.easeInOut(duration: 0.12), value: displayText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func recognitionBottomRow(displayText: String) -> some View {
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

            // 언어 전환
            circleBtn(icon: "arrow.left.arrow.right",
                      fg: Color.secondary,
                      bg: Color(.secondarySystemFill)) {
                store.send(.swapLanguagesTapped)
            }

            Spacer()

            panelLangButton(language: store.bottomLanguage, fg: .primary) {
                store.send(.showBottomPicker)
            }

            // 마이크
            MicButton(isActive: store.isSessionActive && store.activeMic == .bottom,
                      color: kBlue) {
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

    /// 우상단 확장 버튼 (좌우 반전 아이콘)
    private func expandButton(isEmpty: Bool, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.up.right.and.arrow.down.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(fg.opacity(isEmpty ? 0.25 : 0.6))
                .frame(width: 30, height: 30)
                .background(fg.opacity(isEmpty ? 0.05 : 0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        .padding(12)
    }

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
                Text(language.localizedName(in: store.appLanguage))
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
    let isFaceToFace: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // 닫기 버튼
                HStack {
                    Spacer()
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
        // 대면 모드면 전체 뒤집기
        .scaleEffect(x: isFaceToFace ? -1 : 1, y: isFaceToFace ? -1 : 1)
    }
}
