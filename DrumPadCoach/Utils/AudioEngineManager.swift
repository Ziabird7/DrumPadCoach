import AVFoundation
import Combine

/// Shared audio engine manager - single AVAudioEngine instance shared between
/// metronome playback and microphone recording to avoid audio conflicts on iOS
class AudioEngineManager: ObservableObject {
    static let shared = AudioEngineManager()
    
    let engine = AVAudioEngine()
    
    // Metronome playback nodes
    let clickPlayer = AVAudioPlayerNode()
    let accentPlayer = AVAudioPlayerNode()
    
    // State
    @Published var isEngineRunning = false
    var sampleRate: Float = 44100
    
    private var inputTapInstalled = false
    
    private init() {
        setupEngine()
    }
    
    private func setupEngine() {
        // Attach nodes
        engine.attach(clickPlayer)
        engine.attach(accentPlayer)
        
        // Connect to main mixer
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(clickPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(accentPlayer, to: engine.mainMixerNode, format: format)
        
        sampleRate = Float(format.sampleRate)
    }
    
    /// Start the audio engine if not already running
    func startEngine() throws {
        if !engine.isRunning {
            try AudioUtils.shared.configureAudioSession()
            try engine.start()
            isEngineRunning = true
        }
    }
    
    /// Stop the audio engine (only if no taps and no players are playing)
    func stopEngineIfNeeded() {
        // Don't stop if recording tap is still installed
        guard !inputTapInstalled else { return }
        
        engine.stop()
        isEngineRunning = false
    }
    
    /// Install a tap on the input node for recording
    func installInputTap(bufferSize: AVAudioFrameCount,
                         handler: @escaping AVAudioNodeTapBlock) throws {
        guard !inputTapInstalled else { return }
        
        try startEngine()
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        sampleRate = Float(format.sampleRate)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format, block: handler)
        inputTapInstalled = true
    }
    
    /// Remove the input tap
    func removeInputTap() {
        guard inputTapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        inputTapInstalled = false
    }
    
    var isTapInstalled: Bool {
        return inputTapInstalled
    }
}
