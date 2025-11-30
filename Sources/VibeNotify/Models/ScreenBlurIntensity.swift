import Foundation

/// Defines the intensity level for screen blur effects
public enum ScreenBlurIntensity: Equatable, Sendable {
    /// Subtle blur - content still partially visible (radius: 10)
    case light
    /// Balanced blur - good for most notifications (radius: 25)
    case medium
    /// Strong blur - draws full attention to notification (radius: 50)
    case heavy
    /// Custom blur radius (clamped to 0-100)
    case custom(radius: Int)

    /// The blur radius value for this intensity
    public var radius: Int {
        switch self {
        case .light: return 10
        case .medium: return 25
        case .heavy: return 50
        case .custom(let r): return max(0, min(r, 100))
        }
    }
}
