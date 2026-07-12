import Foundation

/// Defines accent patterns for metronome beats
enum AccentMode: String, CaseIterable, Codable {
    /// All beats equal volume — for beginners practicing consistent strokes
    case uniform = "uniform"
    
    /// First beat of each measure is accented (default)
    case downbeat = "downbeat"
    
    /// Backbeat: beats 2 & 4 accented (rock/pop feel, indices 1 & 3 in 4/4)
    case backbeat = "backbeat"
    
    /// Strong on odd beats (1 & 3), weak on even (2 & 4) — indices 0 & 2 strong in 4/4
    case strongWeak = "strongWeak"
    
    /// All beats accented — for practicing power consistency
    case allAccented = "allAccented"
    
    /// Display name in Chinese
    var displayName: String {
        switch self {
        case .uniform: return "均匀"
        case .downbeat: return "首拍重音"
        case .backbeat: return "反拍重音"
        case .strongWeak: return "强弱交替"
        case .allAccented: return "全部重音"
        }
    }
    
    /// Short description for UI hint
    var description: String {
        switch self {
        case .uniform:
            return "所有拍子音量相同，适合基础练习"
        case .downbeat:
            return "每小节第一拍加重，最常见的模式"
        case .backbeat:
            return "第2、4拍加重，摇滚/流行常用节奏感"
        case .strongWeak:
            return "奇数拍强、偶数拍弱，练习力度控制"
        case .allAccented:
            return "所有拍子都加重音，练习力量一致性"
        }
    }
    
    /// Icon for UI
    var iconName: String {
        switch self {
        case .uniform: return "equal.circle"
        case .downbeat: return "1.circle"
        case .backbeat: return "arrow.left.arrow.right.circle"
        case .strongWeak: return "waveform"
        case .allAccented: return "exclamationmark.circle"
        }
    }
    
    /// Determine the volume level for a given beat index within a measure
    /// Returns: .accent (loud), .normal (medium), or .soft (quiet)
    func volumeLevel(for beatIndex: Int, beatsPerMeasure: Int) -> BeatVolumeLevel {
        switch self {
        case .uniform:
            return .normal
            
        case .downbeat:
            return beatIndex == 0 ? .accent : .normal
            
        case .backbeat:
            // In 4/4: accent beats 2 & 4 (indices 1 & 3)
            // In 3/4: accent beat 2 (index 1)
            // In 6/8: accent beats 2 & 5 (indices 1 & 4)
            if beatsPerMeasure == 4 {
                return (beatIndex == 1 || beatIndex == 3) ? .accent : .normal
            } else if beatsPerMeasure == 3 {
                return beatIndex == 1 ? .accent : .normal
            } else { // 6/8
                return (beatIndex == 1 || beatIndex == 4) ? .accent : .normal
            }
            
        case .strongWeak:
            // Strong on even indices (0, 2), weak on odd indices (1, 3)
            return beatIndex % 2 == 0 ? .accent : .soft
            
        case .allAccented:
            return .accent
        }
    }
}

/// Volume level for a single beat
enum BeatVolumeLevel: Hashable {
    case accent   // Loud, higher pitch
    case normal   // Standard click
    case soft     // Quieter, shorter
}
