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
                text: store.translation.translatedText,
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
                text: store.speechRecognition.recognizedText,
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
                    selected: store.translation.targetLanguage,
                    bgColor: kBlue, rowFg: .white, accentColor: .white,
                    bundle: appBundle,
                    appLanguage: store.appLanguage,
                    onSelect: { store.send(.translation(.languageChanged($0))) },
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
        ScrollView(.vertical, showsIndicators: false) {
            translationText
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 130)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 길게 누르면 전체화면 확장
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    guard !store.translation.translatedText.isEmpty else { return }
                    store.send(.expandTopPanel)
                }
        )
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
            // 상단 마이크
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

    // MARK: - 인식/입력 패널 (하단)

    private var recognitionPanel: some View {
        ZStack {
            if store.isBottomPickerPresented {
                LanguagePickerOverlay(
                    selected: store.speechRecognition.sourceLanguage,
                    bgColor: Color(.systemBackground), rowFg: .primary, accentColor: kBlue,
                    bundle: appBundle,
                    appLanguage: store.appLanguage,
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
        ZStack {
            // 음성 인식 결과 텍스트
            recognitionText

            // 길게 누르면 전체화면 확장
            Color.clear
                .contentShape(Rectangle())
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            guard !store.speechRecognition.recognizedText.isEmpty else { return }
                            store.send(.expandBottomPanel)
                        }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            recognitionBottomRow
        }
    }

    private var recognitionText: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // Placeholder
                if store.speechRecognition.recognizedText.isEmpty {
                    Text("마이크를 눌러 말하세요")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                }

                Text(store.speechRecognition.recognizedText.isEmpty
                     ? "　" : store.speechRecognition.recognizedText)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(5)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                    .animation(.easeInOut(duration: 0.12), value: store.speechRecognition.recognizedText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            // 언어 전환
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

            // 마이크
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
