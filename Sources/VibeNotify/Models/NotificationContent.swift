import SwiftUI

/// Protocol for all notification content types (extensible for Lottie/Rive later)
public protocol NotificationContent {
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}

/// Standard notification configuration inspired by swiftDialog
public struct StandardNotification {
    public let title: String?
    public let message: String?
    public let icon: IconType?
    public let buttons: [Button]
    public let style: Style
    public let autoDismiss: AutoDismiss?

    public init(
        title: String? = nil,
        message: String? = nil,
        icon: IconType? = nil,
        buttons: [Button] = [],
        style: Style = .default,
        autoDismiss: AutoDismiss? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.buttons = buttons
        self.style = style
        self.autoDismiss = autoDismiss
    }

    // MARK: - Icon Types
    public enum IconType {
        case system(String)
        case image(NSImage)
        case svg(String) // SVG file path
        case url(URL)

        case success
        case error
        case warning
        case info

        var systemName: String? {
            switch self {
            case .system(let name): return name
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            default: return nil
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            default: return .primary
            }
        }
    }

    // MARK: - Button Configuration
    public struct Button: Identifiable {
        public let id = UUID()
        public let title: String
        public let style: ButtonStyle
        public let action: () -> Void

        public init(title: String, style: ButtonStyle = .primary, action: @escaping () -> Void) {
            self.title = title
            self.style = style
            self.action = action
        }

        public enum ButtonStyle {
            case primary
            case secondary
            case destructive
        }
    }

    // MARK: - Style Configuration
    public struct Style: Sendable {
        public let backgroundColor: Color
        public let cornerRadius: CGFloat
        public let padding: CGFloat
        public let shadow: Shadow?

        public init(
            backgroundColor: Color = Color(NSColor.windowBackgroundColor),
            cornerRadius: CGFloat = 16,
            padding: CGFloat = 24,
            shadow: Shadow? = Shadow()
        ) {
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.padding = padding
            self.shadow = shadow
        }

        public static let `default` = Style()
        public static let minimal = Style(backgroundColor: .clear, cornerRadius: 0, padding: 12, shadow: nil)
        public static let card = Style(backgroundColor: Color(NSColor.controlBackgroundColor), cornerRadius: 12, padding: 20)

        public struct Shadow: Sendable {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat

            public init(color: Color = .black.opacity(0.2), radius: CGFloat = 10, x: CGFloat = 0, y: CGFloat = 4) {
                self.color = color
                self.radius = radius
                self.x = x
                self.y = y
            }
        }
    }

    // MARK: - Auto Dismiss
    public struct AutoDismiss: Sendable {
        public let delay: TimeInterval
        public let indicator: DismissIndicator

        public init(delay: TimeInterval, indicator: DismissIndicator = .none) {
            self.delay = delay
            self.indicator = indicator
        }

        /// Deprecated spelling from before `DismissIndicator` existed.
        /// `true` meant "render the draining bar" — now `.bar`; `false` meant
        /// "render nothing" — now `.none`. Kept so existing call sites (this
        /// library's own `success`/`warning`/`info` convenience constructors,
        /// and the consuming client) keep compiling unchanged.
        ///
        /// `showProgress` has no default here (unlike the old declaration) —
        /// only `init(delay:indicator:)` above owns the single-argument
        /// `AutoDismiss(delay:)` call shape. Defaulting it on both
        /// initializers would make that call shape ambiguous.
        @available(*, deprecated, message: "Use init(delay:indicator:); showProgress: true maps to .bar, false maps to .none")
        public init(delay: TimeInterval, showProgress: Bool) {
            self.delay = delay
            self.indicator = showProgress ? .bar : .none
        }

        /// Backward-compatible reader for the old `Bool` shape. Both existing
        /// renderers (`StandardNotificationView`, `SVGNotificationView`) read
        /// `autoDismiss.showProgress` — this keeps them byte-identical while
        /// the underlying storage is now `indicator`. `true` only for `.bar`,
        /// matching what those renderers historically drew for `showProgress
        /// == true`; `.hairlineRing` is new and has no old-renderer picture,
        /// so it reads as `false` here (nothing draws for it in either
        /// existing renderer, which is correct — a hairline ring is engine
        /// territory added later, not something either renderer already knows
        /// how to draw).
        public var showProgress: Bool {
            indicator == .bar
        }
    }
}

/// The generic "this closes in N" signal — deliberately quiet: no number, no
/// label, just an indication that dismissal is coming. Contrast with
/// `TaskTimer`, which is the large, legible ring/countdown a user is meant to
/// actually read.
public enum DismissIndicator: Sendable, Equatable {
    case none
    case bar
    case hairlineRing
}

/// The large, legible countdown for an exercise the user is meant to read —
/// e.g. "look 20 feet away for 20 seconds". `unitLabel` and `completionLabel`
/// are the caller's words, never inferred by the library.
public struct TaskTimer: Sendable {
    public let duration: TimeInterval
    public let unitLabel: String
    public let completionLabel: String

    public init(duration: TimeInterval, unitLabel: String, completionLabel: String) {
        self.duration = duration
        self.unitLabel = unitLabel
        self.completionLabel = completionLabel
    }
}

/// The pair `show(id:configuration:countdown:content:)` (Task 6) accepts.
/// Either half may be `nil` independently; both `nil` means no clock at all.
/// When both are set they are sequential phases, not a race: the task timer
/// runs first and alone, and the auto-dismiss clock arms the moment the task
/// hits zero, its delay measured from that moment.
public struct Countdown: Sendable {
    public let task: TaskTimer?
    public let autoDismiss: StandardNotification.AutoDismiss?

    public init(task: TaskTimer? = nil, autoDismiss: StandardNotification.AutoDismiss? = nil) {
        self.task = task
        self.autoDismiss = autoDismiss
    }
}

/// SVG source type - supports both local file paths and remote URLs
public enum SVGSource {
    case filePath(String)
    case url(URL)

    var url: URL {
        switch self {
        case .filePath(let path):
            return URL(fileURLWithPath: path)
        case .url(let url):
            return url
        }
    }
}

/// SVG-based notification content
public struct SVGNotification {
    public let svgSource: SVGSource
    public let title: String?
    public let message: String?
    public let svgSize: CGSize
    public let interactive: Bool
    public let autoDismiss: StandardNotification.AutoDismiss?

    public init(
        svgSource: SVGSource,
        title: String? = nil,
        message: String? = nil,
        svgSize: CGSize = CGSize(width: 200, height: 200),
        interactive: Bool = false,
        autoDismiss: StandardNotification.AutoDismiss? = nil
    ) {
        self.svgSource = svgSource
        self.title = title
        self.message = message
        self.svgSize = svgSize
        self.interactive = interactive
        self.autoDismiss = autoDismiss
    }

    /// Convenience initializer for file path (backward compatibility)
    public init(
        svgPath: String,
        title: String? = nil,
        message: String? = nil,
        svgSize: CGSize = CGSize(width: 200, height: 200),
        interactive: Bool = false,
        autoDismiss: StandardNotification.AutoDismiss? = nil
    ) {
        self.init(
            svgSource: .filePath(svgPath),
            title: title,
            message: message,
            svgSize: svgSize,
            interactive: interactive,
            autoDismiss: autoDismiss
        )
    }

    /// Convenience initializer for URL
    public init(
        svgURL: URL,
        title: String? = nil,
        message: String? = nil,
        svgSize: CGSize = CGSize(width: 200, height: 200),
        interactive: Bool = false,
        autoDismiss: StandardNotification.AutoDismiss? = nil
    ) {
        self.init(
            svgSource: .url(svgURL),
            title: title,
            message: message,
            svgSize: svgSize,
            interactive: interactive,
            autoDismiss: autoDismiss
        )
    }
}
