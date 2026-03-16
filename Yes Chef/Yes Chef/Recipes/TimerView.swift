import SwiftUI

struct TimerView: View {
    @ObservedObject var timerState: TimerState
    
    var body: some View {
        if timerState.isActive {
            HStack {
                Text(timeString(from: timerState.timeRemaining))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    timerState.stop()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.accentColor)
                        .frame(width: 20, height: 20)
                        .background(.white.opacity(0.8))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
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
