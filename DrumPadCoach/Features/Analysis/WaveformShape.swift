import SwiftUI

/// SwiftUI Shape for drawing audio waveform
struct WaveformShape: Shape {
    let samples: [Float]
    let hitMarkers: [CGFloat]  // Normalized positions (0-1) of detected hits
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !samples.isEmpty else { return path }
        
        let midY = rect.midY
        let width = rect.width
        let height = rect.height / 2
        
        // Downsample for display
        let samplesPerPixel = max(1, samples.count / Int(width))
        
        // Draw waveform
        path.move(to: CGPoint(x: 0, y: midY))
        
        for x in 0..<Int(width) {
            let sampleIndex = x * samplesPerPixel
            let endIndex = min(sampleIndex + samplesPerPixel, samples.count)
            
            guard sampleIndex < samples.count else { break }
            
            // Find peak in this pixel's samples
            var maxSample: Float = 0
            for i in sampleIndex..<endIndex {
                let absSample = abs(samples[i])
                if absSample > maxSample {
                    maxSample = absSample
                }
            }
            
            let y = midY - height * CGFloat(maxSample)
            path.addLine(to: CGPoint(x: CGFloat(x), y: y))
        }
        
        // Mirror for negative part
        for x in stride(from: Int(width) - 1, through: 0, by: -1) {
            let sampleIndex = x * samplesPerPixel
            let endIndex = min(sampleIndex + samplesPerPixel, samples.count)
            
            guard sampleIndex < samples.count else { continue }
            
            var maxSample: Float = 0
            for i in sampleIndex..<endIndex {
                let absSample = abs(samples[i])
                if absSample > maxSample {
                    maxSample = absSample
                }
            }
            
            let y = midY + height * CGFloat(maxSample)
            path.addLine(to: CGPoint(x: CGFloat(x), y: y))
        }
        
        path.closeSubpath()
        
        return path
    }
}

/// View that displays waveform with hit markers
struct WaveformView: View {
    let samples: [Float]
    let hits: [HitEvent]
    let sampleRate: Float
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Waveform
                WaveformShape(samples: samples, hitMarkers: hitPositions(in: geometry.size.width))
                    .fill(Color.blue.opacity(0.6))
                
                // Hit markers
                ForEach(Array(hits.enumerated()), id: \.offset) { index, hit in
                    let xPos = positionForHit(hit, in: geometry.size.width)
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 2)
                        .offset(x: xPos - geometry.size.width / 2)
                }
                
                // Center line
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
        }
        .frame(height: 120)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func positionForHit(_ hit: HitEvent, in width: CGFloat) -> CGFloat {
        guard !samples.isEmpty else { return 0 }
        let totalDuration = Float(samples.count) / sampleRate
        let normalizedPosition = CGFloat(hit.timestamp / Double(totalDuration))
        return normalizedPosition * width
    }
    
    private func hitPositions(in width: CGFloat) -> [CGFloat] {
        guard !samples.isEmpty else { return [] }
        let totalDuration = Float(samples.count) / sampleRate
        return hits.map { CGFloat($0.timestamp / Double(totalDuration)) * width }
    }
}
