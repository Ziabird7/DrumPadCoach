import Foundation

/// Analysis result for a practice session
struct AnalysisResult: Identifiable {
    let id = UUID()
    let hits: [HitEvent]
    let sampleRate: Float
    let bpm: Int
    let timeSignature: TimeSignature
    let calibration: CalibrationProfile?
    let accentMode: AccentMode

    // MARK: - Timing analysis

    /// Time intervals between consecutive hits
    var timingIntervals: [TimeInterval] {
        guard hits.count > 1 else { return [] }
        return (1..<hits.count).map { hits[$0].timestamp - hits[$0-1].timestamp }
    }

    /// Expected interval based on BPM (in seconds)
    var expectedInterval: TimeInterval {
        60.0 / Double(bpm)
    }

    /// Signed timing deviations: negative = early, positive = late
    var signedTimingDeviations: [TimeInterval] {
        timingIntervals.map { $0 - expectedInterval }
    }

    /// Absolute timing deviations (for scoring)
    var timingDeviations: [TimeInterval] {
        signedTimingDeviations.map { abs($0) }
    }

    var averageTimingDeviation: TimeInterval {
        guard !timingDeviations.isEmpty else { return 0 }
        return timingDeviations.reduce(0, +) / Double(timingDeviations.count)
    }

    var maxTimingDeviation: TimeInterval {
        timingDeviations.max() ?? 0
    }

    var timingStdDev: TimeInterval {
        guard timingDeviations.count > 1 else { return 0 }
        let mean = averageTimingDeviation
        let variance = timingDeviations.map { pow($0 - mean, 2) }.reduce(0, +) / Double(timingDeviations.count - 1)
        return sqrt(variance)
    }

    /// Indices of hits that are early (interval shorter than expected by > 20ms)
    var earlyHitIndices: [Int] {
        signedTimingDeviations.enumerated()
            .filter { $0.element < -0.02 }
            .map { $0.offset }
    }

    /// Indices of hits that are late (interval longer than expected by > 20ms)
    var lateHitIndices: [Int] {
        signedTimingDeviations.enumerated()
            .filter { $0.element > 0.02 }
            .map { $0.offset }
    }

    // MARK: - Volume analysis (with calibration + accent mode awareness)

    /// Raw volumes from hits
    var rawVolumes: [Float] {
        hits.map { $0.peakAmplitude }
    }

    /// Calibrated volumes - normalized using calibration profile if available
    var volumes: [Float] {
        guard let cal = calibration, cal.isValid, hits.count >= 2 else {
            return rawVolumes
        }
        
        let evenVols = hits.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element.peakAmplitude }
        let oddVols = hits.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element.peakAmplitude }
        
        guard !evenVols.isEmpty, !oddVols.isEmpty else { return rawVolumes }
        
        let evenAvg = evenVols.reduce(0, +) / Float(evenVols.count)
        let oddAvg = oddVols.reduce(0, +) / Float(oddVols.count)
        
        let calLeftLouder = cal.leftHandAvgVolume > cal.rightHandAvgVolume
        let evenLouder = evenAvg > oddAvg
        let evenIsLeft = calLeftLouder == evenLouder
        
        return hits.enumerated().map { index, hit in
            let isEvenHand = (index % 2 == 0)
            let isLeftHand = evenIsLeft ? isEvenHand : !isEvenHand
            let factor = isLeftHand ? cal.leftHandNormFactor : cal.rightHandNormFactor
            return hit.peakAmplitude * factor
        }
    }

    /// Whether calibration was applied
    var isCalibrated: Bool {
        calibration?.isValid == true
    }
    
    /// Group hits by expected volume level based on accent mode
    /// Returns groups of volumes that should be similar
    var volumeGroups: (accented: [Float], normal: [Float], soft: [Float]) {
        let beatsPerMeasure = timeSignature.beatsPerMeasure
        var accented: [Float] = []
        var normal: [Float] = []
        var soft: [Float] = []
        
        let vols = volumes
        for (index, vol) in vols.enumerated() {
            let beatInMeasure = index % beatsPerMeasure
            let level = accentMode.volumeLevel(for: beatInMeasure, beatsPerMeasure: beatsPerMeasure)
            switch level {
            case .accent: accented.append(vol)
            case .normal: normal.append(vol)
            case .soft: soft.append(vol)
            }
        }
        return (accented, normal, soft)
    }
    
    /// Whether accent mode has mixed volume levels (requires group analysis)
    var hasMixedAccentLevels: Bool {
        let beatsPerMeasure = timeSignature.beatsPerMeasure
        var levels = Set<BeatVolumeLevel>()
        for beat in 0..<beatsPerMeasure {
            levels.insert(accentMode.volumeLevel(for: beat, beatsPerMeasure: beatsPerMeasure))
        }
        return levels.count > 1
    }

    var averageVolume: Float {
        guard !volumes.isEmpty else { return 0 }
        return volumes.reduce(0, +) / Float(volumes.count)
    }

    var volumeStdDev: Float {
        guard volumes.count > 1 else { return 0 }
        let mean = averageVolume
        let variance = volumes.map { pow($0 - mean, 2) }.reduce(0, +) / Float(volumes.count - 1)
        return sqrt(variance)
    }

    var volumeCV: Float {
        guard averageVolume > 0 else { return 0 }
        return volumeStdDev / averageVolume
    }
    
    /// Accent-aware volume CV: computes CV within each volume group separately,
    /// then returns the weighted average. This doesn't penalize intentional accents.
    var accentAwareVolumeCV: Float {
        guard hasMixedAccentLevels else { return volumeCV }
        
        let groups = volumeGroups
        var totalCV: Float = 0
        var totalCount: Float = 0
        
        for group in [groups.accented, groups.normal, groups.soft] where group.count > 1 {
            let mean = group.reduce(0, +) / Float(group.count)
            guard mean > 0 else { continue }
            let variance = group.map { pow($0 - mean, 2) }.reduce(0, +) / Float(group.count - 1)
            let cv = sqrt(variance) / mean
            let weight = Float(group.count)
            totalCV += cv * weight
            totalCount += weight
        }
        
        return totalCount > 0 ? totalCV / totalCount : volumeCV
    }

    /// Indices of hits with abnormally high volume within their accent group
    var loudHitIndices: [Int] {
        return outlierHitIndices(above: true)
    }

    /// Indices of hits with abnormally low volume within their accent group
    var quietHitIndices: [Int] {
        return outlierHitIndices(above: false)
    }
    
    private func outlierHitIndices(above: Bool) -> [Int] {
        let beatsPerMeasure = timeSignature.beatsPerMeasure
        let vols = volumes
        var result: [Int] = []
        
        // Group indices by volume level
        var groups: [BeatVolumeLevel: [(index: Int, vol: Float)]] = [:]
        for (index, vol) in vols.enumerated() {
            let beatInMeasure = index % beatsPerMeasure
            let level = accentMode.volumeLevel(for: beatInMeasure, beatsPerMeasure: beatsPerMeasure)
            groups[level, default: []].append((index, vol))
        }
        
        // Find outliers within each group
        for (_, group) in groups where group.count >= 3 {
            let groupVols = group.map { $0.vol }
            let mean = groupVols.reduce(0, +) / Float(groupVols.count)
            let variance = groupVols.map { pow($0 - mean, 2) }.reduce(0, +) / Float(groupVols.count - 1)
            let stdDev = sqrt(variance)
            guard stdDev > 0 else { continue }
            
            for item in group {
                if above && item.vol > mean + stdDev * 1.5 {
                    result.append(item.index)
                } else if !above && item.vol < mean - stdDev * 1.5 {
                    result.append(item.index)
                }
            }
        }
        
        return result.sorted()
    }

    // MARK: - Scores (0-100)

    var timingScore: Int {
        let deviation = timingStdDev * 1000
        return max(0, min(100, Int(100 - deviation * 2)))
    }

    var volumeScore: Int {
        max(0, min(100, Int(100 - accentAwareVolumeCV * 200)))
    }

    var overallScore: Int {
        Int(Double(timingScore) * 0.5 + Double(volumeScore) * 0.5)
    }

    // MARK: - Suggestions

    var suggestions: [String] {
        var result: [String] = []

        // Calibration notice
        if isCalibrated {
            result.append("已使用校准数据分析左右手力度")
        }

        // === Timing feedback ===
        if timingScore >= 85 {
            result.append("节奏稳定性很好！")
        } else if timingScore >= 70 {
            result.append("节奏基本稳定，继续保持")
        } else {
            result.append("节奏不够稳定，建议使用节拍器多练习")
        }

        // Find specific problematic beat ranges
        if !earlyHitIndices.isEmpty || !lateHitIndices.isEmpty {
            let earlyRanges = groupConsecutive(earlyHitIndices.map { $0 + 2 })
            let lateRanges = groupConsecutive(lateHitIndices.map { $0 + 2 })

            for range in earlyRanges.prefix(3) {
                let relevantDevs = earlyHitIndices.prefix(5).map { abs(signedTimingDeviations[$0]) * 1000 }
                let avgDev = relevantDevs.reduce(0, +) / Double(max(relevantDevs.count, 1))
                result.append("第\(rangeText(range))拍偏快约\(String(format: "%.0f", avgDev))ms")
            }
            for range in lateRanges.prefix(3) {
                let relevantDevs = lateHitIndices.prefix(5).map { abs(signedTimingDeviations[$0]) * 1000 }
                let avgDev = relevantDevs.reduce(0, +) / Double(max(relevantDevs.count, 1))
                result.append("第\(rangeText(range))拍偏慢约\(String(format: "%.0f", avgDev))ms")
            }
        }

        // Report max deviation beat
        if timingDeviations.count > 1,
           let maxDevIndex = timingDeviations.enumerated().max(by: { $0.element < $1.element })?.offset,
           timingDeviations[maxDevIndex] > 0.03 {
            let direction = signedTimingDeviations[maxDevIndex] < 0 ? "偏快" : "偏慢"
            result.append("第\(maxDevIndex + 2)拍偏差最大（\(direction)\(String(format: "%.1f", timingDeviations[maxDevIndex] * 1000))ms）")
        }

        // === Volume feedback ===
        if volumeScore >= 85 {
            if hasMixedAccentLevels {
                result.append("各重音组内音量控制很好！")
            } else {
                result.append("音量控制很均匀！")
            }
        } else if volumeScore >= 70 {
            result.append("音量基本均匀，注意力度控制")
        } else {
            result.append("音量波动较大，建议加强左右手力度一致性练习")

            // Check for alternating pattern within groups
            let groups = volumeGroups
            for (groupName, group) in [("重音", groups.accented), ("普通", groups.normal)] where group.count >= 4 {
                let even = group.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
                let odd = group.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element }
                let evenAvg = even.reduce(0, +) / Float(even.count)
                let oddAvg = odd.reduce(0, +) / Float(odd.count)
                let diff = abs(evenAvg - oddAvg) / max(evenAvg, oddAvg)
                if diff > 0.15 {
                    let weakHand = evenAvg < oddAvg ? "奇数拍" : "偶数拍"
                    result.append("\(groupName)组内\(weakHand)音量偏弱")
                }
            }

            // Report specific outlier hits within their accent groups
            if !loudHitIndices.isEmpty || !quietHitIndices.isEmpty {
                let loudBeats = loudHitIndices.prefix(5).map { $0 + 1 }
                let quietBeats = quietHitIndices.prefix(5).map { $0 + 1 }
                if !loudBeats.isEmpty {
                    result.append("第\(loudBeats.map { String($0) }.joined(separator: "、"))拍在同组内音量偏高")
                }
                if !quietBeats.isEmpty {
                    result.append("第\(quietBeats.map { String($0) }.joined(separator: "、"))拍在同组内音量偏低")
                }
            }
        }
        
        // Accent mode info
        if hasMixedAccentLevels {
            result.append("已使用「\(accentMode.displayName)」模式分析，音量评估在同组内进行")
        }

        return result
    }

    // MARK: - Helpers

    private func groupConsecutive(_ indices: [Int]) -> [(Int, Int)] {
        guard !indices.isEmpty else { return [] }
        let sorted = indices.sorted()
        var ranges: [(Int, Int)] = []
        var start = sorted[0]
        var end = sorted[0]

        for i in 1..<sorted.count {
            if sorted[i] == end + 1 {
                end = sorted[i]
            } else {
                ranges.append((start, end))
                start = sorted[i]
                end = sorted[i]
            }
        }
        ranges.append((start, end))
        return ranges
    }

    private func rangeText(_ range: (Int, Int)) -> String {
        if range.0 == range.1 {
            return "\(range.0)"
        }
        return "\(range.0)-\(range.1)"
    }
}

enum TimeSignature: String, CaseIterable, Codable {
    case fourFour = "4/4"
    case threeFour = "3/4"
    case sixEight = "6/8"

    var beatsPerMeasure: Int {
        switch self {
        case .fourFour: return 4
        case .threeFour: return 3
        case .sixEight: return 6
        }
    }
}
