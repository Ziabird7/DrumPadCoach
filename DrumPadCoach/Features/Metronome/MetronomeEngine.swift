import AVFoundation
import Combine

/// Metronome audio engine using shared AVAudioEngine for precise timing
class MetronomeEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentBeat = 0
    @Published var bpm: Int = 120
    @Published var timeSignature: TimeSignature = .fourFour
    @Published var subdivisions: Int = 1  // 1=quarter, 2=eighth, 4=sixteenth
    @Published var accentMode: AccentMode = .downbeat
    
    private let audioManager = AudioEngineManager.shared
    
    private var clickBuffer: AVAudioPCMBuffer?
    private var accentBuffer: AVAudioPCMBuffer?
    private var subClickBuffer: AVAudioPCMBuffer?  // Quieter click for subdivisions
    private var softBuffer: AVAudioPCMBuffer?      // Soft click for weak beats
    
    private var schedulerTimer: Timer?
    private var sampleRate: Float = 44100
    
    init() {
        sampleRate = audioManager.sampleRate
        generateClickBuffers()
    }
    
    deinit {
        stop()
    }
    
    private func generateClickBuffers() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        
        // Regular click (1000Hz, normal volume)
        let clickSamples = AudioUtils.shared.generateClickBuffer(sampleRate: sampleRate)
        clickBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(clickSamples.count))!
        clickBuffer!.frameLength = clickBuffer!.frameCapacity
        clickBuffer!.floatChannelData![0].update(from: clickSamples, count: clickSamples.count)
        
        // Accented click (1500Hz, louder)
        let accentSamples = AudioUtils.shared.generateAccentClickBuffer(sampleRate: sampleRate)
        accentBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(accentSamples.count))!
        accentBuffer!.frameLength = accentBuffer!.frameCapacity
        accentBuffer!.floatChannelData![0].update(from: accentSamples, count: accentSamples.count)
        
        // Subdivision click (800Hz, quieter, shorter)
        let subSamples = AudioUtils.shared.generateClickBuffer(sampleRate: sampleRate, frequency: 800, duration: 0.015)
        let softSubSamples = subSamples.map { $0 * 0.5 }
        subClickBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(softSubSamples.count))!
        subClickBuffer!.frameLength = subClickBuffer!.frameCapacity
        subClickBuffer!.floatChannelData![0].update(from: softSubSamples, count: softSubSamples.count)
        
        // Soft beat click (600Hz, reduced volume - for weak beats in strongWeak mode)
        let softSamples = AudioUtils.shared.generateClickBuffer(sampleRate: sampleRate, frequency: 600, duration: 0.018)
        let reducedSamples = softSamples.map { $0 * 0.4 }
        softBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(reducedSamples.count))!
        softBuffer!.frameLength = softBuffer!.frameCapacity
        softBuffer!.floatChannelData![0].update(from: reducedSamples, count: reducedSamples.count)
    }
    
    func start() {
        guard !isPlaying else { return }
        
        do {
            try audioManager.startEngine()
            
            audioManager.clickPlayer.play()
            audioManager.accentPlayer.play()
            
            isPlaying = true
            currentBeat = 0
            
            scheduleNextBeat()
            HapticsManager.shared.tapRigid()
            
        } catch {
            print("Failed to start metronome: \(error)")
        }
    }
    
    func stop() {
        guard isPlaying else { return }
        
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        
        audioManager.clickPlayer.stop()
        audioManager.accentPlayer.stop()
        
        isPlaying = false
        currentBeat = 0
        
        HapticsManager.shared.tapRigid()
    }
    
    private func scheduleNextBeat() {
        guard isPlaying else { return }
        
        let beatsPerMeasure = timeSignature.beatsPerMeasure
        let secondsPerBeat = 60.0 / Double(bpm)
        let subInterval = secondsPerBeat / Double(subdivisions)
        
        // Determine volume level for this beat based on accent mode
        let volume = accentMode.volumeLevel(for: currentBeat, beatsPerMeasure: beatsPerMeasure)
        
        switch volume {
        case .accent:
            if let buffer = accentBuffer {
                audioManager.accentPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            }
            DispatchQueue.main.async {
                HapticsManager.shared.tapMedium()
            }
            
        case .normal:
            if let buffer = clickBuffer {
                audioManager.clickPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            }
            DispatchQueue.main.async {
                HapticsManager.shared.tapLight()
            }
            
        case .soft:
            if let buffer = softBuffer {
                audioManager.clickPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            }
            // No haptic for soft beats
        }
        
        // Schedule subdivision clicks (between main beats)
        if subdivisions > 1 {
            for sub in 1..<subdivisions {
                let delay = Double(sub) * subInterval
                DispatchQueue.main.asyncAfter(deadline: .now() + delay - 0.05) { [weak self] in
                    guard let self = self, self.isPlaying else { return }
                    if let buffer = self.subClickBuffer {
                        self.audioManager.clickPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
                    }
                }
            }
        }
        
        // Update beat counter
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentBeat = (self.currentBeat + 1) % beatsPerMeasure
        }
        
        // Schedule next beat
        let delay = secondsPerBeat - 0.05
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.scheduleNextBeat()
        }
    }
    
    var currentSampleRate: Float {
        return sampleRate
    }
}
