import Foundation

/// Represents a complete practice session with recording data
struct PracticeSession: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
    let bpm: Int
    let timeSignature: TimeSignature
    let audioData: [Float]       // Raw PCM samples
    let sampleRate: Float
    var analysisResult: AnalysisResult?

    init(date: Date, duration: TimeInterval, bpm: Int, timeSignature: TimeSignature,
         audioData: [Float], sampleRate: Float) {
        self.date = date
        self.duration = duration
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.audioData = audioData
        self.sampleRate = sampleRate
    }
}
