import SwiftUI
import ComposableArchitecture
import APIClient

struct LanguageSelectorView: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        HStack(spacing: 16) {
            languagePicker(
                title: "인식",
                selected: store.speechRecognition.sourceLanguage,
                onSelect: { store.send(.speechRecognition(.languageChanged($0))) }
            )

            Image(systemName: "arrow.right")
                .foregroundColor(.gray)
                .font(.system(size: 18, weight: .semibold))

            languagePicker(
                title: "번역",
                selected: store.translation.targetLanguage,
                onSelect: { store.send(.translation(.languageChanged($0))) }
            )
        }
        .padding(.horizontal, 8)
    }

    private func languagePicker(
        title: String,
        selected: SupportedLanguage,
        onSelect: @escaping (SupportedLanguage) -> Void
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)

            Menu {
                ForEach(SupportedLanguage.allCases, id: \.self) { language in
                    Button(language.displayName) { onSelect(language) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selected.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
