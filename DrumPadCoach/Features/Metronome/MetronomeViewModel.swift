import SwiftUI
import Combine

@MainActor
class MetronomeViewModel: ObservableObject {
    @Published var engine = MetronomeEngine()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Restore saved accent mode
        if let saved = UserDefaults.standard.string(forKey: "drumpad_accent_mode"),
           let mode = AccentMode(rawValue: saved) {
            engine.accentMode = mode
        }
        
        // Forward engine state changes
        engine.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        engine.$currentBeat
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    var bpm: Int {
        get { engine.bpm }
        set { engine.bpm = newValue }
    }
    
    var timeSignature: TimeSignature {
        get { engine.timeSignature }
        set { engine.timeSignature = newValue }
    }
    
    var subdivisions: Int {
        get { engine.subdivisions }
        set { engine.subdivisions = newValue }
    }
    
    var accentMode: AccentMode {
        get { engine.accentMode }
        set {
            engine.accentMode = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: "drumpad_accent_mode")
        }
    }
    
    var isPlaying: Bool { engine.isPlaying }
    var currentBeat: Int { engine.currentBeat }
    
    func togglePlay() {
        if engine.isPlaying {
            engine.stop()
        } else {
            engine.start()
        }
    }
    
    func increaseBPM(by amount: Int = 5) {
        bpm = min(240, bpm + amount)
    }
    
    func decreaseBPM(by amount: Int = 5) {
        bpm = max(40, bpm - amount)
    }
}
