import Foundation
import AVFoundation

class AudioLevelMonitor: ObservableObject {
    @Published var level: Float = 0.0
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    
    init() {
        setupRecorder()
    }
    
    func startMonitoring() {
        if recorder?.isRecording == false {
            recorder?.record()
            startTimer()
        }
    }
    
    func stopMonitoring() {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        level = 0.0
    }
    
    private func setupRecorder() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
        let sampleRate = session.sampleRate > 0 ? session.sampleRate : 44100.0
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]
        
        do {
            let url = URL(fileURLWithPath: "/dev/null")
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
        } catch {
            print("Failed to setup audio recorder: \(error)")
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateLevel()
        }
    }
    
    private func updateLevel() {
        recorder?.updateMeters()
        // Get average power for channel 0
        let power = recorder?.averagePower(forChannel: 0) ?? -160.0
        // Normalize power (-160 to 0) to (0 to 1)
        // Typical speech is around -20 to 0 dB
        // Let's map -60...0 to 0...1 for better visuals
        let minDb: Float = -60.0
        let normalized = max(0.0, (power - minDb) / abs(minDb))
        
        DispatchQueue.main.async {
            self.level = normalized
        }
    }
}
