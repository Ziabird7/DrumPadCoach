import UIKit

/// Manages haptic feedback for metronome beats
class HapticsManager {
    static let shared = HapticsManager()
    
    private init() {}
    
    /// Trigger a light haptic tap (for regular beats)
    func tapLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Trigger a medium haptic tap (for accented beats)
    func tapMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Trigger a rigid haptic (for metronome start/stop)
    func tapRigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Trigger success notification (for good practice results)
    func notifySuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// Trigger warning notification
    func notifyWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}
