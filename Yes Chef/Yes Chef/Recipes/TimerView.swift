import SwiftUI

struct TimerView: View {
    @ObservedObject var timerState: TimerState
    
    var body: some View {
        if timerState.isActive {
            HStack(spacing: 6) {
                Text(timeString(from: timerState.timeRemaining))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    timerState.stop()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(14)
            .background(Color.accentColor)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }
    
    private func timeString(from totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
