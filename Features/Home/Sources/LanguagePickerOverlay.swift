import SwiftUI
import APIClient

/// 패널 내부 오버레이로 그려지기 때문에
/// 대면 모드(180° 회전) 시 패널과 함께 자동으로 뒤집혀 보임
struct LanguagePickerOverlay: View {
    let selected: SupportedLanguage
    let bgColor: Color
    let rowFg: Color
    let accentColor: Color
    let onSelect: (SupportedLanguage) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            bgColor

            VStack(spacing: 0) {
                header
                Divider().opacity(0.2)
                languageList
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                    Text(String(localized: "picker.back", bundle: .module))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(rowFg.opacity(0.9))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    // MARK: - 언어 목록

    private var languageList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(SupportedLanguage.allCases, id: \.self) { lang in
                    languageRow(lang)
                    if lang != SupportedLanguage.allCases.last {
                        Divider().padding(.leading, 68).opacity(0.12)
                    }
                }
            }
        }
    }

    private func languageRow(_ lang: SupportedLanguage) -> some View {
        Button {
            onSelect(lang)
            onDismiss()
        } label: {
            HStack(spacing: 16) {
                Text(lang.flag)
                    .font(.system(size: 28))
                Text(lang.displayName)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(rowFg)
                Spacer()
                if lang == selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accentColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(lang == selected ? accentColor.opacity(0.08) : Color.clear)
    }
}
