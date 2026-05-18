import SwiftUI
import ComposableArchitecture
import APIClient
import DesignSystem
import Translation
import Speech
import UIKit

struct SettingsView: View {
    let store: StoreOf<HomeReducer>

    @State private var modelStatus: [SupportedLanguage: LanguageAvailability.Status] = [:]
    @State private var sttStatus: [SupportedLanguage: Bool] = [:]

    private var bundle: Bundle {
        Bundle.localizedModule(language: store.appLanguage)
    }

    private var pivotLanguage: SupportedLanguage { store.bottomLanguage }

    private var downloadConfiguration: TranslationSession.Configuration? {
        guard let target = store.pendingTranslationDownload else { return nil }
        return TranslationSession.Configuration(
            source: Locale.Language(identifier: pivotLanguage.bcp47Code),
            target: Locale.Language(identifier: target.bcp47Code)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            headerRow
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    languageCard
                    translationCard
                    modelsCard
                    sttCard
                    versionFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task(id: pivotLanguage) {
            await refreshModelStatus()
        }
        .task {
            refreshSttStatus()
        }
        .onChange(of: store.isSettingsPresented) { _, isPresented in
            if isPresented { refreshSttStatus() }
        }
        .translationTask(downloadConfiguration) { session in
            try? await session.prepareTranslation()
            await refreshModelStatus()
            await MainActor.run {
                store.send(.translationDownloadFinished)
            }
        }
    }

    private func refreshModelStatus() async {
        let availability = LanguageAvailability()
        let source = Locale.Language(identifier: pivotLanguage.bcp47Code)
        for lang in SupportedLanguage.allCases where lang != pivotLanguage {
            let target = Locale.Language(identifier: lang.bcp47Code)
            let status = await availability.status(from: source, to: target)
            await MainActor.run {
                modelStatus[lang] = status
            }
        }
    }

    // MARK: - 드래그 핸들

    private var dragHandle: some View {
        Capsule()
            .fill(Color(.systemFill))
            .frame(width: 36, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    // MARK: - 헤더

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "settings.title", bundle: bundle))
                    .font(.system(size: 24, weight: .bold))
                Text("すらすら")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            Button { store.send(.settingsDismissed) } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 30))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - 언어 카드

    private var languageCard: some View {
        settingsCard(
            icon: "globe",
            iconColor: Color.orange,
            title: String(localized: "settings.language", bundle: bundle)
        ) {
            VStack(spacing: 0) {
                ForEach(Array(languageOptions.enumerated()), id: \.offset) { idx, opt in
                    languageRow(code: opt.code, flag: opt.flag, name: opt.name)
                    if idx < languageOptions.count - 1 {
                        Divider().padding(.leading, 44).opacity(0.4)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var languageOptions: [(code: String, flag: String, name: String)] {
        [
            ("",        "⚙️", String(localized: "settings.language.system", bundle: bundle)),
            ("ko",      "🇰🇷", "한국어"),
            ("en",      "🇺🇸", "English"),
            ("ja",      "🇯🇵", "日本語"),
            ("zh-Hans", "🇨🇳", "中文 (简体)"),
        ]
    }

    private func languageRow(code: String, flag: String, name: String) -> some View {
        Button {
            store.send(.appLanguageChanged(code))
        } label: {
            HStack(spacing: 12) {
                Text(flag)
                    .font(.system(size: 20))
                    .frame(width: 28)
                Text(name)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.primary)
                Spacer()
                if store.appLanguage == code {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignTokens.accentBlue)
                }
            }
            .padding(.vertical, 10)
            // 행 전체가 터치 영역이 되도록 명시적으로 확장
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 번역 카드

    private var translationCard: some View {
        settingsCard(
            icon: "speaker.wave.2.fill",
            iconColor: DesignTokens.accentBlue,
            title: String(localized: "settings.translation", bundle: bundle)
        ) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(String(localized: "settings.auto_speak", bundle: bundle))
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { store.isAutoSpeakEnabled },
                        set: { _ in store.send(.autoSpeakToggled) }
                    ))
                    .labelsHidden()
                    .tint(DesignTokens.accentBlue)
                }
                .padding(.top, 2)

                Divider()
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Text(String(localized: "settings.auto_speak.footer", bundle: bundle))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 번역 모델 다운로드 카드

    private var modelsCard: some View {
        settingsCard(
            icon: "arrow.down.circle.fill",
            iconColor: Color.green,
            title: "번역 모델"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("기준 언어 \(pivotLanguage.flag) \(pivotLanguage.localizedName(in: store.appLanguage))와의 페어를 미리 받을 수 있습니다.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                let langs = SupportedLanguage.allCases.filter { $0 != pivotLanguage }
                ForEach(Array(langs.enumerated()), id: \.element) { idx, lang in
                    modelRow(lang)
                    if idx < langs.count - 1 {
                        Divider().padding(.leading, 44).opacity(0.4)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func modelRow(_ lang: SupportedLanguage) -> some View {
        let status = modelStatus[lang]
        let isDownloading = store.pendingTranslationDownload == lang

        return HStack(spacing: 12) {
            Text(lang.flag)
                .font(.system(size: 20))
                .frame(width: 28)
            Text(lang.localizedName(in: store.appLanguage))
                .font(.system(size: 16))
                .foregroundStyle(Color.primary)
            Spacer()
            modelStatusView(status: status, isDownloading: isDownloading, lang: lang)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func modelStatusView(
        status: LanguageAvailability.Status?,
        isDownloading: Bool,
        lang: SupportedLanguage
    ) -> some View {
        if isDownloading {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("다운로드 중")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }
        } else if let status = status {
            switch status {
            case .installed:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("설치됨")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.green)
                }
            case .supported:
                Button {
                    store.send(.requestTranslationDownload(lang))
                } label: {
                    Text("다운로드")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.accentBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(DesignTokens.accentBlue.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .disabled(store.pendingTranslationDownload != nil)
            case .unsupported:
                Text("지원 안 함")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            @unknown default:
                EmptyView()
            }
        } else {
            ProgressView().controlSize(.small)
        }
    }

    // MARK: - 음성 인식 모델 카드

    private var sttCard: some View {
        settingsCard(
            icon: "mic.fill",
            iconColor: Color.red,
            title: "음성 인식 모델"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("iOS의 받아쓰기 언어와 연동됩니다. 미설치 언어는 아래 버튼으로 iOS 설정에서 추가하세요.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)

                Button(action: openDictationSettings) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 14))
                        Text("iOS 설정에서 받아쓰기 언어 관리")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .opacity(0.5)
                    }
                    .foregroundStyle(DesignTokens.accentBlue)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DesignTokens.accentBlue.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)

                let langs = Array(SupportedLanguage.allCases)
                ForEach(Array(langs.enumerated()), id: \.element) { idx, lang in
                    sttRow(lang)
                    if idx < langs.count - 1 {
                        Divider().padding(.leading, 44).opacity(0.4)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func sttRow(_ lang: SupportedLanguage) -> some View {
        let supported = sttStatus[lang] ?? false
        return HStack(spacing: 12) {
            Text(lang.flag)
                .font(.system(size: 20))
                .frame(width: 28)
            Text(lang.localizedName(in: store.appLanguage))
                .font(.system(size: 16))
                .foregroundStyle(Color.primary)
            Spacer()
            if supported {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("설치됨")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.green)
                }
            } else {
                Text("미설치")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refreshSttStatus() {
        var newStatus: [SupportedLanguage: Bool] = [:]
        for lang in SupportedLanguage.allCases {
            let installed = SFSpeechRecognizer(locale: lang.sttLocale)?.supportsOnDeviceRecognition ?? false
            newStatus[lang] = installed
        }
        sttStatus = newStatus
    }

    private func openDictationSettings() {
        // 후보 URL을 순서대로 시도: 키보드/받아쓰기 직링크 → 일반 → 루트 → 앱 설정
        let candidates: [String] = [
            "App-prefs:General&path=Keyboard/DICTATION",
            "App-prefs:Keyboard",
            "App-prefs:General",
            "App-prefs:",
            UIApplication.openSettingsURLString,
        ]
        openURLCandidates(candidates, index: 0)
    }

    private func openURLCandidates(_ candidates: [String], index: Int) {
        guard index < candidates.count, let url = URL(string: candidates[index]) else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                openURLCandidates(candidates, index: index + 1)
            }
        }
    }

    // MARK: - 버전

    private var versionFooter: some View {
        Text("v1.0.0")
            .font(.system(size: 12))
            .foregroundStyle(Color(.tertiaryLabel))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }

    // MARK: - 카드 컨테이너

    private func settingsCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }

            Divider()

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }
}

