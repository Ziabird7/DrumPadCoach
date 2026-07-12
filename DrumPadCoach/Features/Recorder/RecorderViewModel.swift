import SwiftUI
import Combine

@MainActor
class RecorderViewModel: ObservableObject {
    @Published var recorder = AudioRecorderEngine()
    @Published var metronomeVM = MetronomeViewModel()
    @Published var recordedAudioData: [Float] = []
    @Published var recordedSampleRate: Float = 44100
    @Published var hasRecording = false
    @Published var micPermissionGranted = false
    @Published var showingPermissionAlert = false
    
    private var cancellables = Set<AnyCancellable>()
    
    var isRecording: Bool { recorder.isRecording }
    var recordingDuration: TimeInterval { recorder.recordingDuration }
    var currentLevels: Float { recorder.currentLevels }
    var liveSamples: [Float] { recorder.liveSamples }
    var bpm: Int { metronomeVM.bpm }
    var timeSignature: TimeSignature { metronomeVM.timeSignature }
    
    init() {
        recorder.onRecordingComplete = { [weak self] samples, sampleRate in
            Task { @MainActor in
                self?.recordedAudioData = samples
                self?.recordedSampleRate = sampleRate
                self?.hasRecording = true
            }
        }
        
        // Forward live samples changes
        recorder.$liveSamples
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func requestMicPermission() {
        AudioUtils.shared.requestMicrophonePermission { [weak self] granted in
            Task { @MainActor in
                self?.micPermissionGranted = granted
                if !granted {
                    self?.showingPermissionAlert = true
                }
            }
        }
    }
    
    func startPractice() {
        guard micPermissionGranted else {
            requestMicPermission()
            return
        }
        
        // Start metronome and recording together
        metronomeVM.engine.start()
        recorder.startRecording()
    }
    
    func stopPractice() {
        recorder.stopRecording()
        metronomeVM.engine.stop()
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration - Double(Int(duration))) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
}
