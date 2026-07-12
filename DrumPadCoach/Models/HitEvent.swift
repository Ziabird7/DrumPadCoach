import Foundation

/// Represents a single drum hit event detected from audio
struct HitEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: TimeInterval  // Time in seconds from start of recording
    let peakAmplitude: Float     // Peak amplitude (0.0 - 1.0)
    let rmsEnergy: Float         // RMS energy around the hit

    init(timestamp: TimeInterval, peakAmplitude: Float, rmsEnergy: Float = 0) {
        self.id = UUID()
        self.timestamp = timestamp
        self.peakAmplitude = peakAmplitude
        self.rmsEnergy = rmsEnergy
    }
}
