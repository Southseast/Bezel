import Foundation
import CoreGraphics

enum BarSettings {
    static let enabled = "barEnabled"
    static let builtInOnly = "barBuiltInOnly"
    static let roundedCorners = "barRoundedCorners"
    static let animated = "barAnimated"
    static let launchAtLogin = "barLaunchAtLogin"

    /// Blend height for displays without a real notch (matches the typical
    /// menu bar row so the band reads as an extended bezel).
    static let fallbackNotchHeight: CGFloat = 32

    static func bool(_ key: String, default defaultValue: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    /// Fallback used when a key has never been written.
    static func defaultValue(for key: String) -> Bool {
        switch key {
        case enabled: true
        case roundedCorners, animated: true
        default: false
        }
    }
}
