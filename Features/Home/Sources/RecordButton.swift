import SwiftUI

struct RecordButton: View {
    let isActive: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // 펄스 링 (녹음 중)
                if isActive {
                    Circle()
                        .stroke(Color.red.opacity(0.35), lineWidth: 2)
                        .frame(width: 96, height: 96)
                        .scaleEffect(isPulsing ? 1.45 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.1).repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }

                // 버튼 본체
                Circle()
                    .fill(isActive ? Color.red : Color(.label))
                    .frame(width: 68, height: 68)
                    .shadow(
                        color: isActive ? Color.red.opacity(0.45) : Color.black.opacity(0.18),
                        radius: 12, x: 0, y: 4
                    )

                // 아이콘
                Image(systemName: isActive ? "stop.fill" : "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isActive ? Color.white : Color(.systemBackground))
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if isActive { isPulsing = true }
        }
        .onChange(of: isActive) { _, newValue in
            isPulsing = newValue
        }
    }
}
