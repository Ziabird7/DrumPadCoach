import AVFoundation
import Combine

/// Audio recording engine using shared AVAudioEngine for real-time PCM capture
class AudioRecorderEngine: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentLevels: Float = 0  // Real-time audio level
    @Published var liveSamples: [Float] = []  // Live waveform samples for display
    
    private let audioManager = AudioEngineManager.shared
    private var recordedSamples: [Float] = []
    private var sampleRate: Float = 44100
    private var durationTimer: Timer?
    private let samplesLock = NSLock()
    
    /// Callback when recording stops with the recorded PCM data
    var onRecordingComplete: (([Float], Float) -> Void)?
    
    /// Callback for live sample updates (for waveform display)
    var onLiveSamplesUpdate: (([Float]) -> Void)?
    
    init() {
        sampleRate = audioManager.sampleRate
    }
    
    deinit {
        stopRecording()
    }
    
    /// Start recording from microphone via shared engine
    func startRecording() {
        guard !isRecording else { return }
        
        do {
            recordedSamples.removeAll()
            liveSamples.removeAll()
            
            try audioManager.installInputTap(bufferSize: 1024) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }
            
            isRecording = true
            recordingDuration = 0
            
            // Timer for updating duration display
            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.recordingDuration += 0.1
                }
            }
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    /// Stop recording and return captured audio data
    func stopRecording() {
        guard isRecording else { return }
        
        audioManager.removeInputTap()
        
        durationTimer?.invalidate()
        durationTimer = nil
        
        isRecording = false
        
        samplesLock.lock()
        let samples = recordedSamples
        samplesLock.unlock()
        
        onRecordingComplete?(samples, sampleRate)
    }
    
    /// Process incoming audio buffer from the shared engine tap
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var samples = [Float](repeating: 0, count: frameLength)
        
        for i in 0..<frameLength {
            samples[i] = channelData[i]
        }
        
        // Store samples
        samplesLock.lock()
        recordedSamples.append(contentsOf: samples)
        samplesLock.unlock()
        
        // Calculate current level for UI
        let rms = AudioUtils.shared.calculateRMS(samples: samples)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLevels = rms
            
            // Provide latest chunk for live waveform display
            self.samplesLock.lock()
            let allSamples = self.recordedSamples
            self.samplesLock.unlock()
            
            // Keep last ~3 seconds for live display
            let displayLength = min(allSamples.count, Int(self.sampleRate * 3))
            let startIdx = allSamples.count - displayLength
            self.liveSamples = Array(allSamples[startIdx...])
        }
    }
    
    /// Get all recorded samples
    func getRecordedSamples() -> [Float] {
        samplesLock.lock()
        defer { samplesLock.unlock() }
        return recordedSamples
    }
    
    /// Get the sample rate
    func getSampleRate() -> Float {
        return sampleRate
    }
}
