import SwiftUI
import ComposableArchitecture
import APIClient

struct LanguageSelectorView: View {
    let store: StoreOf<HomeReducer>
    @State private var swapAngle: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            // 출발 언어
            languagePicker(
                language: store.speechRecognition.sourceLanguage,
                onSelect: { store.send(.speechRecognition(.languageChanged($0))) }
            )

            // 스왑 버튼
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    swapAngle += 180
                }
                store.send(.swapLanguagesTapped)
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill), in: Circle())
                    .rotationEffect(.degrees(swapAngle))
            }
            .buttonStyle(.plain)

            // 도착 언어
            languagePicker(
                language: store.translation.targetLanguage,
                onSelect: { store.send(.translation(.languageChanged($0))) }
            )
        }
    }

    private func languagePicker(
        language: SupportedLanguage,
        onSelect: @escaping (SupportedLanguage) -> Void
    ) -> some View {
        Menu {
            ForEach(SupportedLanguage.allCases, id: \.self) { lang in
                Button {
                    onSelect(lang)
                } label: {
                    Label(lang.displayName, image: "")
                        .labelStyle(.titleOnly)
                }
            }
        } label: {
            pickerLabel(language)
        }
        .buttonStyle(.plain)
    }

    private func pickerLabel(_ language: SupportedLanguage) -> some View {
        HStack(spacing: 6) {
            Text(language.flag)
                .font(.system(size: 18))
            Text(language.shortName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))
    }
}
