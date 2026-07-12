import SwiftUI
import Combine

/// Manages the calibration wizard - recording left/right hand baseline volumes
@MainActor
class CalibrationViewModel: ObservableObject {
    enum CalibrationStep: Int, CaseIterable {
        case intro = 0
        case leftHand = 1
        case rightHand = 2
        case result = 3
    }
    
    @Published var currentStep: CalibrationStep = .intro
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentLevel: Float = 0
    @Published var detectedTapCount: Int = 0
    @Published var liveSamples: [Float] = []
    @Published var leftHandProfile: (avg: Float, stdDev: Float, count: Int)?
    @Published var rightHandProfile: (avg: Float, stdDev: Float, count: Int)?
    @Published var calibrationProfile: CalibrationProfile?
    @Published var existingProfile: CalibrationProfile?
    
    /// Target number of taps per hand
    let targetTaps = 6
    
    /// BPM for calibration (comfortable slow tempo)
    let calibrationBPM = 80
    
    private let recorder = AudioRecorderEngine()
    private let hitDetector = HitDetector()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        existingProfile = CalibrationStore.shared.profile
        
        // Forward recorder state
        recorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        recorder.$currentLevels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.currentLevel = level
            }
            .store(in: &cancellables)
        
        recorder.$liveSamples
            .receive(on: DispatchQueue.main)
            .sink { [weak self] samples in
                self?.liveSamples = samples
            }
            .store(in: &cancellables)
        
        recorder.$recordingDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dur in
                self?.recordingDuration = dur
            }
            .store(in: &cancellables)
    }
    
    var handName: String {
        switch currentStep {
        case .leftHand: return "左手"
        case .rightHand: return "右手"
        default: return ""
        }
    }
    
    var progress: Double {
        switch currentStep {
        case .intro: return 0
        case .leftHand: return 0.33
        case .rightHand: return 0.66
        case .result: return 1.0
        }
    }
    
    /// Start recording for the current hand
    func startHandRecording() {
        detectedTapCount = 0
        recorder.startRecording()
        isRecording = true
    }
    
    /// Stop recording and analyze taps for the current hand
    func stopHandRecording() {
        recorder.stopRecording()
        isRecording = false
        
        // Small delay to ensure all samples are processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.analyzeHandRecording()
        }
    }
    
    /// Analyze the recorded taps for current hand
    private func analyzeHandRecording() {
        let samples = recorder.getRecordedSamples()
        let sampleRate = recorder.getSampleRate()
        
        let hits = hitDetector.detectHits(samples: samples, sampleRate: sampleRate)
        detectedTapCount = hits.count
        
        guard hits.count >= 3 else {
            // Not enough taps detected - stay on current step and let user retry
            return
        }
        
        let volumes = hits.map { $0.peakAmplitude }
        let avg = volumes.reduce(0, +) / Float(volumes.count)
        let stdDev = volumes.count > 1 ?
            sqrt(volumes.map { pow($0 - avg, 2) }.reduce(0, +) / Float(volumes.count - 1)) : 0
        
        let profile = (avg: avg, stdDev: stdDev, count: hits.count)
        
        switch currentStep {
        case .leftHand:
            leftHandProfile = profile
            currentStep = .rightHand
        case .rightHand:
            rightHandProfile = profile
            finalizeCalibration()
        default:
            break
        }
    }
    
    /// Create and save the final calibration profile
    private func finalizeCalibration() {
        guard let left = leftHandProfile, let right = rightHandProfile else { return }
        
        let profile = CalibrationProfile(
            leftHandAvgVolume: left.avg,
            leftHandStdDev: left.stdDev,
            rightHandAvgVolume: right.avg,
            rightHandStdDev: right.stdDev,
            sampleCount: min(left.count, right.count),
            calibratedAt: Date()
        )
        
        calibrationProfile = profile
        CalibrationStore.shared.profile = profile
        existingProfile = profile
        currentStep = .result
    }
    
    /// Skip calibration and use default (no normalization)
    func skipCalibration() {
        CalibrationStore.shared.clear()
        existingProfile = nil
    }
    
    /// Reset to start over
    func reset() {
        currentStep = .intro
        leftHandProfile = nil
        rightHandProfile = nil
        calibrationProfile = nil
        detectedTapCount = 0
    }
}
