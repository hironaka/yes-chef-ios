import Foundation
import AVFoundation
import ActivityKit
import UserNotifications

@MainActor
class TimerState: ObservableObject {
    @Published var timeRemaining: Int = 0
    @Published var isActive: Bool = false
    
    private var timerTask: Task<Void, Never>?
    private var duration: Int = 0
    private var audioPlayer: AVAudioPlayer?
    private var currentActivity: Activity<TimerAttributes>?
    
    init() {
        setupAudio()
        requestNotificationPermission()
        restoreActivity()
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
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func scheduleNotification(for endTime: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "Your recipe timer has finished!"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("kitchen-timer-33043.mp3"))
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "kitchenTimer", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["kitchenTimer"])
    }
    
    private func restoreActivity() {
        for activity in Activity<TimerAttributes>.activities {
            if activity.activityState == .active {
                self.currentActivity = activity
                self.isActive = true
                
                let contentState = activity.content.state
                let remaining = contentState.estimatedEndTime.timeIntervalSinceNow
                
                if remaining > 0 {
                    if contentState.isPaused {
                        // Timer is paused, restore remaining time without starting task
                        self.timeRemaining = Int(ceil(remaining))
                    } else {
                        // Timer is actively running
                        self.timeRemaining = Int(ceil(remaining))
                        startTask(with: remaining)
                    }
                } else if !contentState.isPaused {
                    // Timer finished while app was backgrounded/closed
                    self.timeRemaining = 0
                    self.audioPlayer?.play()
                    
                    // Update activity to finished state
                    Task {
                        let contentState = TimerAttributes.ContentState(isPaused: false, estimatedEndTime: Date())
                        let content = ActivityContent(state: contentState, staleDate: nil)
                        await activity.end(content, dismissalPolicy: .default)
                    }
                }
            }
        }
    }

    func start(duration: Int) {
        print("Starting timer with duration \(duration)")
        self.duration = duration
        self.timeRemaining = duration
        self.isActive = true
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        
        let expectedEndDate = Date().addingTimeInterval(TimeInterval(duration))
        scheduleNotification(for: expectedEndDate)
        
        // End existing activity if any
        if let existing = currentActivity {
            Task {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
        }
        
        let attributes = TimerAttributes(timerName: "Cooking Timer")
        let contentState = TimerAttributes.ContentState(isPaused: false, estimatedEndTime: expectedEndDate)
        let content = ActivityContent(state: contentState, staleDate: nil)
        
        do {
            currentActivity = try Activity.request(attributes: attributes, content: content)
        } catch {
            print("Failed to request activity: \(error)")
        }
        
        startTask(with: TimeInterval(duration))
    }
    
    func stop() {
        self.isActive = false
        self.timeRemaining = 0
        timerTask?.cancel()
        timerTask = nil
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        
        cancelNotification()
        
        Task {
            let contentState = TimerAttributes.ContentState(isPaused: false, estimatedEndTime: Date())
            let content = ActivityContent(state: contentState, staleDate: nil)
            await currentActivity?.end(content, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
    }
    
    func pause() {
        timerTask?.cancel()
        timerTask = nil
        cancelNotification() // Cancel alarm since it's paused
        
        Task {
            let estimatedEndTime = Date().addingTimeInterval(TimeInterval(timeRemaining))
            let contentState = TimerAttributes.ContentState(isPaused: true, estimatedEndTime: estimatedEndTime)
            let content = ActivityContent(state: contentState, staleDate: nil)
            await currentActivity?.update(content)
        }
    }
    
    func resume() {
        guard timeRemaining > 0 else { return }
        let expectedEndDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
        scheduleNotification(for: expectedEndDate)
        
        Task {
            let contentState = TimerAttributes.ContentState(isPaused: false, estimatedEndTime: expectedEndDate)
            let content = ActivityContent(state: contentState, staleDate: nil)
            await currentActivity?.update(content)
        }
        
        startTask(with: TimeInterval(timeRemaining))
    }
    
    private func startTask(with timeInterval: TimeInterval) {
        let expectedEndDate = Date().addingTimeInterval(timeInterval)
        
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
            
            if timeRemaining <= 0 && !Task.isCancelled {
                audioPlayer?.play()
                
                // End activity on completion
                Task {
                    let contentState = TimerAttributes.ContentState(isPaused: false, estimatedEndTime: Date())
                    let content = ActivityContent(state: contentState, staleDate: nil)
                    await currentActivity?.end(content, dismissalPolicy: .default)
                    currentActivity = nil
                }
            }
        }
    }
}
