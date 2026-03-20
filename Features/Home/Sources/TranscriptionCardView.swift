import SwiftUI

struct TranscriptionCardView: View {
    let title: String
    let text: String
    var isActive: Bool = false
    var isFlipped: Bool = false
    var onSpeakTapped: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.0)

                Spacer()

                if let onSpeakTapped {
                    Button(action: onSpeakTapped) {
                        Image(systemName: isActive ? "speaker.wave.3.fill" : "speaker.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isActive ? Color.accentColor : .secondary)
                            .symbolEffect(.variableColor, isActive: isActive)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 본문 텍스트 (크고 선명하게)
            ScrollView {
                Text(text.isEmpty ? "·  ·  ·" : text)
                    .font(.system(size: 22, weight: .medium, design: .default))
                    .foregroundStyle(text.isEmpty ? Color.secondary.opacity(0.4) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(6)
                    .animation(.easeInOut(duration: 0.15), value: text)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            isActive ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.08),
                            lineWidth: 1.5
                        )
                }
        }
        .rotationEffect(isFlipped ? .degrees(180) : .zero)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isFlipped)
    }
}
