import SwiftUI

struct RecordButton: View {
    let isActive: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // 펄스 효과 (녹음 중일 때)
                if isActive {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }

                // 버튼 본체
                Circle()
                    .fill(isActive ? Color.red : Color.white)
                    .frame(width: 76, height: 76)
                    .shadow(color: isActive ? .red.opacity(0.5) : .white.opacity(0.3),
                            radius: 16, x: 0, y: 4)

                // 아이콘
                Image(systemName: isActive ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(isActive ? .white : .black)
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
