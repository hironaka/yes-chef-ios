import Foundation

@MainActor
class TimerState: ObservableObject {
    @Published var timeRemaining: Int = 0
    @Published var isRunning: Bool = false
    
    private var timerTask: Task<Void, Never>?
    private var duration: Int = 0
    
    func start(duration: Int) {
        self.duration = duration
        self.timeRemaining = duration
        self.isRunning = true
        startTask()
    }
    
    func stop() {
        self.isRunning = false
        self.timeRemaining = 0
        timerTask?.cancel()
        timerTask = nil
    }
    
    func pause() {
        self.isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }
    
    func resume() {
        guard timeRemaining > 0 else { return }
        self.isRunning = true
        startTask()
    }
    
    private func startTask() {
        timerTask?.cancel()
        timerTask = Task {
            while timeRemaining > 0 && isRunning {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    if !Task.isCancelled {
                        timeRemaining -= 1
                    }
                } catch {
                    break
                }
            }
            if timeRemaining == 0 {
                isRunning = false
            }
        }
    }
}
