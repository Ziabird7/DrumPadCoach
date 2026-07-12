import AVFoundation
import UIKit

/// Audio utility functions for configuration and processing
class AudioUtils {
    static let shared = AudioUtils()
    
    private init() {}
    
    /// Configure audio session for recording and playback
    func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try session.setActive(true)
    }
    
    /// Request microphone permission
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    /// Calculate RMS (Root Mean Square) energy of audio samples
    func calculateRMS(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
    
    /// Convert amplitude to decibels
    func amplitudeToDecibels(amplitude: Float) -> Float {
        guard amplitude > 0 else { return -Float.infinity }
        return 20 * log10(amplitude)
    }
    
    /// Generate a short click sound buffer for metronome
    func generateClickBuffer(sampleRate: Float, frequency: Float = 1000, duration: Float = 0.02) -> [Float] {
        let numSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: numSamples)
        
        for i in 0..<numSamples {
            let t = Float(i) / sampleRate
            // Generate sine wave with exponential decay envelope
            let envelope = exp(-t * 50)  // Fast decay
            samples[i] = sin(2 * .pi * frequency * t) * envelope * 0.8
        }
        
        return samples
    }
    
    /// Generate an accented click (higher pitch, louder)
    func generateAccentClickBuffer(sampleRate: Float) -> [Float] {
        return generateClickBuffer(sampleRate: sampleRate, frequency: 1500, duration: 0.025)
    }
}
