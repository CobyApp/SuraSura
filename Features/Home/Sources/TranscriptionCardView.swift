import SwiftUI

struct TranscriptionCardView: View {
    let title: String
    let text: String
    var isActive: Bool = false
    var onSpeakTapped: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 헤더
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Spacer()

                // 스피커 버튼 (번역 카드에만 표시)
                if let onSpeakTapped {
                    Button(action: onSpeakTapped) {
                        Image(systemName: isActive ? "speaker.wave.3.fill" : "speaker.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isActive ? .blue : .gray)
                            .symbolEffect(.variableColor, isActive: isActive)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 본문
            ScrollView {
                Text(text.isEmpty ? "..." : text)
                    .font(.body)
                    .foregroundColor(text.isEmpty ? .gray.opacity(0.4) : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.2), value: text)
            }
            .frame(maxHeight: 120)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(isActive ? 0.12 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isActive ? Color.blue.opacity(0.4) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}
