import SwiftUI
import ComposableArchitecture
import APIClient

struct LanguageSelectorView: View {
    let store: StoreOf<HomeReducer>
    @State private var isSwapping = false

    var body: some View {
        HStack(spacing: 0) {
            // 출발 언어
            languagePicker(
                selected: store.speechRecognition.sourceLanguage,
                onSelect: { store.send(.speechRecognition(.languageChanged($0))) }
            )

            // 양방향 스왑 버튼
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    isSwapping.toggle()
                }
                store.send(.swapLanguagesTapped)
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
                    .rotationEffect(.degrees(isSwapping ? 180 : 0))
            }
            .buttonStyle(.plain)

            // 도착 언어
            languagePicker(
                selected: store.translation.targetLanguage,
                onSelect: { store.send(.translation(.languageChanged($0))) }
            )
        }
        .padding(.horizontal, 16)
    }

    private func languagePicker(
        selected: SupportedLanguage,
        onSelect: @escaping (SupportedLanguage) -> Void
    ) -> some View {
        Menu {
            ForEach(SupportedLanguage.allCases, id: \.self) { language in
                Button(language.displayName) { onSelect(language) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selected.flag)
                    .font(.title3)
                Text(selected.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .opacity(0.6)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
