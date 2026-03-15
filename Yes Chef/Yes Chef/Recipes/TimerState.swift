import Foundation
import AVFoundation

@MainActor
class TimerState: ObservableObject {
    @Published var timeRemaining: Int = 0
    @Published var isActive: Bool = false
    
    private var timerTask: Task<Void, Never>?
    private var duration: Int = 0
    private var audioPlayer: AVAudioPlayer?
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        guard let url = Bundle.main.url(forResource: "kitchen-timer-33043", withExtension: "mp3") else {
            print("Could not find kitchen-timer-33043.mp3")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize audio player: \(error)")
        }
    }
    
    func start(duration: Int) {
        self.duration = duration
        self.timeRemaining = duration
        self.isActive = true
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        startTask()
    }
    
    func stop() {
        self.isActive = false
        self.timeRemaining = 0
        timerTask?.cancel()
        timerTask = nil
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
    }
    
    func pause() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    func resume() {
        guard timeRemaining > 0 else { return }
        startTask()
    }
    
    private func startTask() {
        let expectedEndDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
        
        timerTask?.cancel()
        timerTask = Task {
            while isActive {
                let remaining = expectedEndDate.timeIntervalSinceNow
                
                if remaining <= 0 {
                    if !Task.isCancelled {
                        timeRemaining = 0
                    }
                    break
                }
                
                if !Task.isCancelled {
                    let newTimeRemaining = Int(ceil(remaining))
                    if newTimeRemaining != timeRemaining {
                        timeRemaining = newTimeRemaining
                    }
                }
                
                do {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                } catch {
                    break
                }
            }
            
            if timeRemaining == 0 && !Task.isCancelled {
                audioPlayer?.play()
            }
        }
    }
}
