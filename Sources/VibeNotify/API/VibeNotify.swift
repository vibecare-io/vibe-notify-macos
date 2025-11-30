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
        position: OverlayWindowManager.WindowPosition? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        windowLevel: OverlayWindowManager.WindowLevel = .floating,
        moveable: Bool = false,
        alwaysOnTop: Bool = true,
        transparent: Bool = false,
        transparentMaterial: NSVisualEffectView.Material = .hudWindow,
        windowOpacity: CGFloat = 1.0,
        screenBlur: Bool = false,
        screenBlurMaterial: NSVisualEffectView.Material = .underWindowBackground,
        screenBlurIntensity: ScreenBlurIntensity? = nil,
        dismissOnScreenTap: Bool = false,
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

        let config = OverlayWindowManager.Configuration(
            presentationMode: presentationMode,
            position: position,
            width: width,
            height: height,
            windowLevel: windowLevel,
            backgroundColor: .clear,
            isTransparent: true,
            ignoresMouseEvents: false,
            isMoveable: moveable,
            alwaysOnTop: alwaysOnTop,
            transparent: transparent,
            transparentMaterial: transparentMaterial,
            windowOpacity: windowOpacity,
            screenBlur: screenBlur,
            screenBlurMaterial: screenBlurMaterial,
            screenBlurIntensity: screenBlurIntensity,
            dismissOnScreenTap: dismissOnScreenTap,
            animatePresentation: true
        )

        return showNotification(notification, configuration: config)
    }

    /// Show an SVG-based notification from a file path
    @discardableResult
    public func showSVG(
        svgPath: String,
        title: String? = nil,
        message: String? = nil,
        svgSize: CGSize = CGSize(width: 200, height: 200),
        interactive: Bool = false,
        presentationMode: OverlayWindowManager.PresentationMode = .toast(corner: .topRight, size: CGSize(width: 300, height: 400)),
        position: OverlayWindowManager.WindowPosition? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        windowLevel: OverlayWindowManager.WindowLevel = .floating,
        moveable: Bool = false,
        alwaysOnTop: Bool = true,
        transparent: Bool = false,
        transparentMaterial: NSVisualEffectView.Material = .hudWindow,
        windowOpacity: CGFloat = 1.0,
        screenBlur: Bool = false,
        screenBlurMaterial: NSVisualEffectView.Material = .underWindowBackground,
        screenBlurIntensity: ScreenBlurIntensity? = nil,
        dismissOnScreenTap: Bool = false,
        autoDismiss: StandardNotification.AutoDismiss? = nil
    ) -> UUID {
        let notification = SVGNotification(
            svgPath: svgPath,
            title: title,
            message: message,
            svgSize: svgSize,
            interactive: interactive,
            autoDismiss: autoDismiss
        )

        let config = OverlayWindowManager.Configuration(
            presentationMode: presentationMode,
            position: position,
            width: width,
            height: height,
            windowLevel: windowLevel,
            backgroundColor: .clear,
            isTransparent: true,
            ignoresMouseEvents: false,
            isMoveable: moveable,
            alwaysOnTop: alwaysOnTop,
            transparent: transparent,
            transparentMaterial: transparentMaterial,
            windowOpacity: windowOpacity,
            screenBlur: screenBlur,
            screenBlurMaterial: screenBlurMaterial,
            screenBlurIntensity: screenBlurIntensity,
            dismissOnScreenTap: dismissOnScreenTap,
            animatePresentation: true
        )

        return showSVGNotification(notification, configuration: config)
    }

    /// Show an SVG-based notification from a URL
    @discardableResult
    public func showSVG(
        svgURL: URL,
        title: String? = nil,
        message: String? = nil,
        svgSize: CGSize = CGSize(width: 200, height: 200),
        interactive: Bool = false,
        presentationMode: OverlayWindowManager.PresentationMode = .toast(corner: .topRight, size: CGSize(width: 300, height: 400)),
        position: OverlayWindowManager.WindowPosition? = nil,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        windowLevel: OverlayWindowManager.WindowLevel = .floating,
        moveable: Bool = false,
        alwaysOnTop: Bool = true,
        transparent: Bool = false,
        transparentMaterial: NSVisualEffectView.Material = .hudWindow,
        windowOpacity: CGFloat = 1.0,
        screenBlur: Bool = false,
        screenBlurMaterial: NSVisualEffectView.Material = .underWindowBackground,
        screenBlurIntensity: ScreenBlurIntensity? = nil,
        dismissOnScreenTap: Bool = false,
        autoDismiss: StandardNotification.AutoDismiss? = nil
    ) -> UUID {
        let notification = SVGNotification(
            svgURL: svgURL,
            title: title,
            message: message,
            svgSize: svgSize,
            interactive: interactive,
            autoDismiss: autoDismiss
        )

        let config = OverlayWindowManager.Configuration(
            presentationMode: presentationMode,
            position: position,
            width: width,
            height: height,
            windowLevel: windowLevel,
            backgroundColor: .clear,
            isTransparent: true,
            ignoresMouseEvents: false,
            isMoveable: moveable,
            alwaysOnTop: alwaysOnTop,
            transparent: transparent,
            transparentMaterial: transparentMaterial,
            windowOpacity: windowOpacity,
            screenBlur: screenBlur,
            screenBlurMaterial: screenBlurMaterial,
            screenBlurIntensity: screenBlurIntensity,
            dismissOnScreenTap: dismissOnScreenTap,
            animatePresentation: true
        )

        return showSVGNotification(notification, configuration: config)
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
        configuration: OverlayWindowManager.Configuration
    ) -> UUID {
        let id = UUID()

        windowManager.show(id: id, configuration: configuration) {
            StandardNotificationView(
                notification: notification,
                transparent: configuration.transparent,
                transparentMaterial: configuration.transparentMaterial
            ) { [weak self] in
                self?.dismiss(id: id)
            }
        }

        activeNotificationIDs.append(id)
        return id
    }

    private func showSVGNotification(
        _ notification: SVGNotification,
        configuration: OverlayWindowManager.Configuration
    ) -> UUID {
        let id = UUID()

        windowManager.show(id: id, configuration: configuration) {
            SVGNotificationView(
                notification: notification,
                screenBlurActive: configuration.screenBlur
            ) { [weak self] in
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
    private var position: OverlayWindowManager.WindowPosition?
    private var width: CGFloat?
    private var height: CGFloat?
    private var windowLevel: OverlayWindowManager.WindowLevel = .floating
    private var moveable: Bool = false
    private var alwaysOnTop: Bool = true
    private var transparent: Bool = false
    private var transparentMaterial: NSVisualEffectView.Material = .hudWindow
    private var windowOpacity: CGFloat = 1.0
    private var screenBlur: Bool = false
    private var screenBlurMaterial: NSVisualEffectView.Material = .underWindowBackground
    private var screenBlurIntensity: ScreenBlurIntensity?
    private var dismissOnScreenTap: Bool = false
    private var autoDismiss: StandardNotification.AutoDismiss?

    // SVG mode
    private var useSVG: Bool = false
    private var svgPath: String?
    private var svgURL: URL?
    private var svgSize: CGSize = CGSize(width: 200, height: 200)
    private var svgInteractive: Bool = false

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

    public func position(_ position: OverlayWindowManager.WindowPosition) -> Self {
        self.position = position
        return self
    }

    public func width(_ width: CGFloat) -> Self {
        self.width = width
        return self
    }

    public func height(_ height: CGFloat) -> Self {
        self.height = height
        return self
    }

    public func moveable(_ moveable: Bool = true) -> Self {
        self.moveable = moveable
        return self
    }

    public func alwaysOnTop(_ alwaysOnTop: Bool = true) -> Self {
        self.alwaysOnTop = alwaysOnTop
        return self
    }

    public func transparent(_ enabled: Bool = true, material: NSVisualEffectView.Material = .hudWindow) -> Self {
        self.transparent = enabled
        self.transparentMaterial = material
        return self
    }

    public func windowOpacity(_ opacity: CGFloat) -> Self {
        self.windowOpacity = opacity
        return self
    }

    /// Enable screen blur with legacy material-based blur (NSVisualEffectView)
    public func screenBlur(_ enabled: Bool = true, material: NSVisualEffectView.Material = .underWindowBackground) -> Self {
        self.screenBlur = enabled
        self.screenBlurMaterial = material
        self.screenBlurIntensity = nil
        return self
    }

    /// Enable screen blur with configurable intensity (recommended)
    /// - Parameters:
    ///   - enabled: Whether to enable screen blur
    ///   - intensity: The blur intensity level (.light, .medium, .heavy, or .custom(radius:))
    public func screenBlur(_ enabled: Bool = true, intensity: ScreenBlurIntensity) -> Self {
        self.screenBlur = enabled
        self.screenBlurIntensity = intensity
        return self
    }

    public func dismissOnScreenTap(_ enabled: Bool = true) -> Self {
        self.dismissOnScreenTap = enabled
        return self
    }

    public func autoDismiss(after delay: TimeInterval, showProgress: Bool = false) -> Self {
        self.autoDismiss = StandardNotification.AutoDismiss(delay: delay, showProgress: showProgress)
        return self
    }

    public func svg(_ path: String, size: CGSize = CGSize(width: 200, height: 200), interactive: Bool = false) -> Self {
        self.useSVG = true
        self.svgPath = path
        self.svgSize = size
        self.svgInteractive = interactive
        return self
    }

    public func svgURL(_ url: URL, size: CGSize = CGSize(width: 200, height: 200), interactive: Bool = false) -> Self {
        self.useSVG = true
        self.svgURL = url
        self.svgSize = size
        self.svgInteractive = interactive
        return self
    }

    @discardableResult
    public func show() -> UUID {
        if useSVG {
            if let svgURL = svgURL {
                return VibeNotify.shared.showSVG(
                    svgURL: svgURL,
                    title: title,
                    message: message,
                    svgSize: svgSize,
                    interactive: svgInteractive,
                    presentationMode: presentationMode,
                    position: position,
                    width: width,
                    height: height,
                    windowLevel: windowLevel,
                    moveable: moveable,
                    alwaysOnTop: alwaysOnTop,
                    transparent: transparent,
                    transparentMaterial: transparentMaterial,
                    windowOpacity: windowOpacity,
                    screenBlur: screenBlur,
                    screenBlurMaterial: screenBlurMaterial,
                    screenBlurIntensity: screenBlurIntensity,
                    dismissOnScreenTap: dismissOnScreenTap,
                    autoDismiss: autoDismiss
                )
            } else if let svgPath = svgPath {
                return VibeNotify.shared.showSVG(
                    svgPath: svgPath,
                    title: title,
                    message: message,
                    svgSize: svgSize,
                    interactive: svgInteractive,
                    presentationMode: presentationMode,
                    position: position,
                    width: width,
                    height: height,
                    windowLevel: windowLevel,
                    moveable: moveable,
                    alwaysOnTop: alwaysOnTop,
                    transparent: transparent,
                    transparentMaterial: transparentMaterial,
                    windowOpacity: windowOpacity,
                    screenBlur: screenBlur,
                    screenBlurMaterial: screenBlurMaterial,
                    screenBlurIntensity: screenBlurIntensity,
                    dismissOnScreenTap: dismissOnScreenTap,
                    autoDismiss: autoDismiss
                )
            }
        }

        return VibeNotify.shared.show(
            title: title,
            message: message,
            icon: icon,
            buttons: buttons,
            style: style,
            presentationMode: presentationMode,
            position: position,
            width: width,
            height: height,
            windowLevel: windowLevel,
            moveable: moveable,
            alwaysOnTop: alwaysOnTop,
            transparent: transparent,
            transparentMaterial: transparentMaterial,
            windowOpacity: windowOpacity,
            screenBlur: screenBlur,
            screenBlurMaterial: screenBlurMaterial,
            screenBlurIntensity: screenBlurIntensity,
            dismissOnScreenTap: dismissOnScreenTap,
            autoDismiss: autoDismiss
        )
    }
}
