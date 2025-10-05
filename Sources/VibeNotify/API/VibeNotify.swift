import SwiftUI

/// Main API for VibeNotify - Declarative notification overlay system for macOS
@MainActor
public final class VibeNotify {

    // MARK: - Singleton
    public static let shared = VibeNotify()

    private let windowManager = OverlayWindowManager.shared
    private var activeNotificationIDs: [UUID] = []

    private init() {}

    // MARK: - Standard Notifications

    /// Show a standard notification with swiftDialog-inspired configuration
    @discardableResult
    public func show(
        title: String? = nil,
        message: String? = nil,
        icon: StandardNotification.IconType? = nil,
        buttons: [StandardNotification.Button] = [],
        style: StandardNotification.Style = .default,
        presentationMode: OverlayWindowManager.PresentationMode = .banner(edge: .top, height: 120),
        windowLevel: OverlayWindowManager.WindowLevel = .floating,
        autoDismiss: StandardNotification.AutoDismiss? = nil
    ) -> UUID {
        let notification = StandardNotification(
            title: title,
            message: message,
            icon: icon,
            buttons: buttons,
            style: style,
            autoDismiss: autoDismiss
        )

        return showNotification(notification, presentationMode: presentationMode, windowLevel: windowLevel)
    }

    /// Show an SVG-based notification
    @discardableResult
    public func showSVG(
        svgPath: String,
        title: String? = nil,
        message: String? = nil,
        svgSize: CGSize = CGSize(width: 200, height: 200),
        interactive: Bool = false,
        presentationMode: OverlayWindowManager.PresentationMode = .toast(corner: .topRight, size: CGSize(width: 300, height: 400)),
        windowLevel: OverlayWindowManager.WindowLevel = .floating
    ) -> UUID {
        let notification = SVGNotification(
            svgPath: svgPath,
            title: title,
            message: message,
            svgSize: svgSize,
            interactive: interactive
        )

        return showSVGNotification(notification, presentationMode: presentationMode, windowLevel: windowLevel)
    }

    /// Show a custom SwiftUI view as a notification
    @discardableResult
    public func showCustom<Content: View>(
        presentationMode: OverlayWindowManager.PresentationMode = .fullScreen,
        windowLevel: OverlayWindowManager.WindowLevel = .floating,
        backgroundColor: NSColor = .clear,
        ignoresMouseEvents: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) -> UUID {
        let id = UUID()

        let config = OverlayWindowManager.Configuration(
            presentationMode: presentationMode,
            windowLevel: windowLevel,
            backgroundColor: backgroundColor,
            isTransparent: true,
            ignoresMouseEvents: ignoresMouseEvents,
            animatePresentation: true
        )

        windowManager.show(id: id, configuration: config) {
            content()
        }

        activeNotificationIDs.append(id)
        return id
    }

    // MARK: - Dismissal

    /// Dismiss a specific notification by ID
    public func dismiss(id: UUID, animated: Bool = true) {
        windowManager.dismiss(id: id, animated: animated)
        activeNotificationIDs.removeAll { $0 == id }
    }

    /// Dismiss all active notifications
    public func dismissAll(animated: Bool = true) {
        windowManager.dismissAll(animated: animated)
        activeNotificationIDs.removeAll()
    }

    // MARK: - Convenience Methods

    /// Show a success notification
    @discardableResult
    public func success(
        title: String = "Success",
        message: String,
        autoDismiss: TimeInterval? = 3.0
    ) -> UUID {
        show(
            title: title,
            message: message,
            icon: .success,
            autoDismiss: autoDismiss.map { StandardNotification.AutoDismiss(delay: $0, showProgress: true) }
        )
    }

    /// Show an error notification
    @discardableResult
    public func error(
        title: String = "Error",
        message: String,
        buttons: [StandardNotification.Button] = []
    ) -> UUID {
        show(
            title: title,
            message: message,
            icon: .error,
            buttons: buttons.isEmpty ? [StandardNotification.Button(title: "OK", action: {})] : buttons
        )
    }

    /// Show a warning notification
    @discardableResult
    public func warning(
        title: String = "Warning",
        message: String,
        autoDismiss: TimeInterval? = 5.0
    ) -> UUID {
        show(
            title: title,
            message: message,
            icon: .warning,
            autoDismiss: autoDismiss.map { StandardNotification.AutoDismiss(delay: $0, showProgress: true) }
        )
    }

    /// Show an info notification
    @discardableResult
    public func info(
        title: String = "Info",
        message: String,
        autoDismiss: TimeInterval? = 4.0
    ) -> UUID {
        show(
            title: title,
            message: message,
            icon: .info,
            autoDismiss: autoDismiss.map { StandardNotification.AutoDismiss(delay: $0, showProgress: true) }
        )
    }

    // MARK: - Private Helpers

    private func showNotification(
        _ notification: StandardNotification,
        presentationMode: OverlayWindowManager.PresentationMode,
        windowLevel: OverlayWindowManager.WindowLevel
    ) -> UUID {
        let id = UUID()

        let config = OverlayWindowManager.Configuration(
            presentationMode: presentationMode,
            windowLevel: windowLevel,
            backgroundColor: .clear,
            isTransparent: true,
            ignoresMouseEvents: false,
            animatePresentation: true
        )

        windowManager.show(id: id, configuration: config) {
            StandardNotificationView(notification: notification) { [weak self] in
                self?.dismiss(id: id)
            }
        }

        activeNotificationIDs.append(id)
        return id
    }

    private func showSVGNotification(
        _ notification: SVGNotification,
        presentationMode: OverlayWindowManager.PresentationMode,
        windowLevel: OverlayWindowManager.WindowLevel
    ) -> UUID {
        let id = UUID()

        let config = OverlayWindowManager.Configuration(
            presentationMode: presentationMode,
            windowLevel: windowLevel,
            backgroundColor: .clear,
            isTransparent: true,
            ignoresMouseEvents: false,
            animatePresentation: true
        )

        windowManager.show(id: id, configuration: config) {
            SVGNotificationView(notification: notification) { [weak self] in
                self?.dismiss(id: id)
            }
        }

        activeNotificationIDs.append(id)
        return id
    }
}

// MARK: - Builder API (Optional Declarative Approach)

public extension VibeNotify {
    /// Create a notification builder for more complex configurations
    static func builder() -> NotificationBuilder {
        NotificationBuilder()
    }
}

@MainActor
public class NotificationBuilder {
    private var title: String?
    private var message: String?
    private var icon: StandardNotification.IconType?
    private var buttons: [StandardNotification.Button] = []
    private var style: StandardNotification.Style = .default
    private var presentationMode: OverlayWindowManager.PresentationMode = .banner(edge: .top, height: 120)
    private var windowLevel: OverlayWindowManager.WindowLevel = .floating
    private var autoDismiss: StandardNotification.AutoDismiss?

    public func title(_ title: String) -> Self {
        self.title = title
        return self
    }

    public func message(_ message: String) -> Self {
        self.message = message
        return self
    }

    public func icon(_ icon: StandardNotification.IconType) -> Self {
        self.icon = icon
        return self
    }

    public func button(_ button: StandardNotification.Button) -> Self {
        self.buttons.append(button)
        return self
    }

    public func style(_ style: StandardNotification.Style) -> Self {
        self.style = style
        return self
    }

    public func presentationMode(_ mode: OverlayWindowManager.PresentationMode) -> Self {
        self.presentationMode = mode
        return self
    }

    public func windowLevel(_ level: OverlayWindowManager.WindowLevel) -> Self {
        self.windowLevel = level
        return self
    }

    public func autoDismiss(after delay: TimeInterval, showProgress: Bool = false) -> Self {
        self.autoDismiss = StandardNotification.AutoDismiss(delay: delay, showProgress: showProgress)
        return self
    }

    @discardableResult
    public func show() -> UUID {
        VibeNotify.shared.show(
            title: title,
            message: message,
            icon: icon,
            buttons: buttons,
            style: style,
            presentationMode: presentationMode,
            windowLevel: windowLevel,
            autoDismiss: autoDismiss
        )
    }
}
