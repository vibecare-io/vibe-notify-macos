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
    public struct AutoDismiss {
        public let delay: TimeInterval
        public let showProgress: Bool

        public init(delay: TimeInterval, showProgress: Bool = false) {
            self.delay = delay
            self.showProgress = showProgress
        }
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
