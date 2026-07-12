import Foundation

/// Detects drum hits from PCM audio data using transient peak detection
class HitDetector {
    /// Configuration for hit detection
    struct Config {
        var frameSize: Int = 512              // Samples per frame for RMS calculation
        var windowSize: Int = 20              // Number of frames for sliding window average
        var thresholdMultiplier: Float = 3.0  // Multiplier above average to detect hit
        var minHitInterval: TimeInterval = 0.05  // Minimum interval between hits (50ms debounce)
    }
    
    let config: Config
    
    init(config: Config = Config()) {
        self.config = config
    }
    
    /// Detect hits in PCM audio samples
    /// - Parameters:
    ///   - samples: Float array of PCM samples (-1.0 to 1.0)
    ///   - sampleRate: Sample rate of the audio
    /// - Returns: Array of detected HitEvents
    func detectHits(samples: [Float], sampleRate: Float) -> [HitEvent] {
        guard samples.count > config.frameSize else { return [] }
        
        // Step 1: Calculate RMS energy for each frame
        let frameEnergies = calculateFrameEnergies(samples: samples)
        guard !frameEnergies.isEmpty else { return [] }
        
        // Step 2: Calculate sliding window average energy
        let windowedAverages = calculateWindowedAverages(energies: frameEnergies)
        
        // Step 3: Detect peaks above adaptive threshold
        var hits: [HitEvent] = []
        var aboveThreshold = false
        var peakFrameIndex = 0
        var peakEnergy: Float = 0
        
        for i in 0..<frameEnergies.count {
            let energy = frameEnergies[i]
            let threshold = windowedAverages[i] * config.thresholdMultiplier
            
            if energy > threshold {
                if !aboveThreshold {
                    // Start of a potential hit
                    aboveThreshold = true
                    peakFrameIndex = i
                    peakEnergy = energy
                } else if energy > peakEnergy {
                    // Found a higher peak within the hit
                    peakFrameIndex = i
                    peakEnergy = energy
                }
            } else {
                if aboveThreshold {
                    // End of hit - record the peak
                    let timestamp = Double(peakFrameIndex * config.frameSize) / Double(sampleRate)
                    let hit = HitEvent(
                        timestamp: timestamp,
                        peakAmplitude: sqrt(peakEnergy),  // Convert RMS to amplitude approximation
                        rmsEnergy: peakEnergy
                    )
                    hits.append(hit)
                    aboveThreshold = false
                }
            }
        }
        
        // Handle case where recording ends during a hit
        if aboveThreshold {
            let timestamp = Double(peakFrameIndex * config.frameSize) / Double(sampleRate)
            let hit = HitEvent(
                timestamp: timestamp,
                peakAmplitude: sqrt(peakEnergy),
                rmsEnergy: peakEnergy
            )
            hits.append(hit)
        }
        
        // Step 4: Debounce - merge hits that are too close together
        let debouncedHits = debounceHits(hits)
        
        return debouncedHits
    }
    
    /// Calculate RMS energy for each frame
    private func calculateFrameEnergies(samples: [Float]) -> [Float] {
        let numFrames = samples.count / config.frameSize
        var energies = [Float](repeating: 0, count: numFrames)
        
        for frameIndex in 0..<numFrames {
            let startSample = frameIndex * config.frameSize
            let endSample = startSample + config.frameSize
            
            var sumOfSquares: Float = 0
            for i in startSample..<endSample {
                sumOfSquares += samples[i] * samples[i]
            }
            
            energies[frameIndex] = sumOfSquares / Float(config.frameSize)
        }
        
        return energies
    }
    
    /// Calculate sliding window average of energies
    private func calculateWindowedAverages(energies: [Float]) -> [Float] {
        let windowSize = config.windowSize
        var averages = [Float](repeating: 0, count: energies.count)
        
        for i in 0..<energies.count {
            let start = max(0, i - windowSize / 2)
            let end = min(energies.count, i + windowSize / 2)
            
            var sum: Float = 0
            var count = 0
            for j in start..<end {
                sum += energies[j]
                count += 1
            }
            
            averages[i] = count > 0 ? sum / Float(count) : 0
        }
        
        return averages
    }
    
    /// Merge hits that are too close together (debounce)
    private func debounceHits(_ hits: [HitEvent]) -> [HitEvent] {
        guard hits.count > 1 else { return hits }
        
        var result: [HitEvent] = [hits[0]]
        
        for i in 1..<hits.count {
            let currentHit = hits[i]
            let lastHit = result.last!
            
            let interval = currentHit.timestamp - lastHit.timestamp
            
            if interval < config.minHitInterval {
                // Too close - keep the one with higher amplitude
                if currentHit.peakAmplitude > lastHit.peakAmplitude {
                    result[result.count - 1] = currentHit
                }
            } else {
                result.append(currentHit)
            }
        }
        
        return result
    }
}
