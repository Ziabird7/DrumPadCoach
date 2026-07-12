import Foundation

/// Stores calibration data for left and right hand volume baselines
/// Used to normalize analysis when phone mic is at different distances from each hand
struct CalibrationProfile: Codable, Equatable {
    let leftHandAvgVolume: Float
    let leftHandStdDev: Float
    let rightHandAvgVolume: Float
    let rightHandStdDev: Float
    let sampleCount: Int           // Number of taps used per hand
    let calibratedAt: Date
    
    /// Ratio of left to right volume (left/right)
    /// > 1.0 means left hand sounds louder at mic position
    /// < 1.0 means right hand sounds louder at mic position
    var volumeRatio: Float {
        guard rightHandAvgVolume > 0.001 else { return 1.0 }
        return leftHandAvgVolume / rightHandAvgVolume
    }
    
    /// Normalization factors to equalize left/right hand volumes
    /// Apply these to detected hit volumes before analysis
    var leftHandNormFactor: Float {
        let avg = (leftHandAvgVolume + rightHandAvgVolume) / 2.0
        guard leftHandAvgVolume > 0.001 else { return 1.0 }
        return avg / leftHandAvgVolume
    }
    
    var rightHandNormFactor: Float {
        let avg = (leftHandAvgVolume + rightHandAvgVolume) / 2.0
        guard rightHandAvgVolume > 0.001 else { return 1.0 }
        return avg / rightHandAvgVolume
    }
    
    /// Whether calibration data looks valid
    var isValid: Bool {
        leftHandAvgVolume > 0.001 && rightHandAvgVolume > 0.001 && sampleCount >= 3
    }
    
    /// Create an empty/invalid calibration
    static let empty = CalibrationProfile(
        leftHandAvgVolume: 0, leftHandStdDev: 0,
        rightHandAvgVolume: 0, rightHandStdDev: 0,
        sampleCount: 0, calibratedAt: Date()
    )
}

/// Manages calibration profile persistence via UserDefaults
class CalibrationStore {
    static let shared = CalibrationStore()
    private let key = "drumpad_calibration_profile"
    
    private init() {}
    
    var profile: CalibrationProfile? {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(CalibrationProfile.self, from: data)
        }
        set {
            if let profile = newValue, let data = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(data, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
