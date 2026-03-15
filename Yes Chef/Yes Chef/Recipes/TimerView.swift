import SwiftUI

struct TimerView: View {
    @ObservedObject var timerState: TimerState
    
    var body: some View {
        if timerState.isRunning || timerState.timeRemaining > 0 {
            HStack {
                Text(timeString(from: timerState.timeRemaining))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Button(action: {
                    timerState.stop()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.8))
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
