import SwiftUI
import Combine

@MainActor
class AnalysisViewModel: ObservableObject {
    @Published var analysisResult: AnalysisResult?
    @Published var hits: [HitEvent] = []
    @Published var isAnalyzing = false
    @Published var audioData: [Float] = []
    @Published var sampleRate: Float = 44100
    @Published var calibrationUsed: CalibrationProfile?
    
    private let hitDetector = HitDetector()
    
    func analyze(audioData: [Float], sampleRate: Float, bpm: Int, timeSignature: TimeSignature,
                 calibration: CalibrationProfile? = nil,
                 accentMode: AccentMode = .downbeat) {
        isAnalyzing = true
        self.audioData = audioData
        self.sampleRate = sampleRate
        self.calibrationUsed = calibration
        
        // Perform hit detection
        let detectedHits = hitDetector.detectHits(samples: audioData, sampleRate: sampleRate)
        self.hits = detectedHits
        
        // Create analysis result with calibration
        let result = AnalysisResult(
            hits: detectedHits,
            sampleRate: sampleRate,
            bpm: bpm,
            timeSignature: timeSignature,
            calibration: calibration,
            accentMode: accentMode
        )
        
        self.analysisResult = result
        self.isAnalyzing = false
        
        // Trigger haptic feedback based on score
        if result.overallScore >= 80 {
            HapticsManager.shared.notifySuccess()
        } else {
            HapticsManager.shared.notifyWarning()
        }
    }
    
    func reset() {
        analysisResult = nil
        hits = []
        audioData = []
        calibrationUsed = nil
        isAnalyzing = false
    }
}
