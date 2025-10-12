import AppKit
import SwiftUI

/// Custom NSWindow subclass that handles ESC key to dismiss
class DismissibleWindow: NSWindow {
    var onEscapePressed: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // Check if ESC key was pressed (keyCode 53)
        if event.keyCode == 53 {
            onEscapePressed?()
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool {
        return true
    }
}

/// Manages overlay windows for notifications with customizable presentation modes
@MainActor
public class OverlayWindowManager {

    // MARK: - Singleton
    public static let shared = OverlayWindowManager()

    // MARK: - Properties
    private var activeWindows: [UUID: NSWindow] = [:]
    private var blurWindows: [UUID: NSWindow] = [:]

    // MARK: - Window Level Presets
    public enum WindowLevel {
        case normal
        case floating
        case popup
        case screenSaver

        var nsWindowLevel: NSWindow.Level {
            switch self {
            case .normal: return .normal
            case .floating: return .floating
            case .popup: return .popUpMenu
            case .screenSaver: return .screenSaver
            }
        }
    }

    // MARK: - Window Position (swiftDialog-inspired)
    public enum WindowPosition {
        case topLeft, left, bottomLeft
        case top, center, bottom
        case topRight, right, bottomRight

        // Alternative spelling
        public static var centre: WindowPosition { .center }
    }

    // MARK: - Presentation Mode
    public enum PresentationMode {
        case fullScreen
        case banner(edge: BannerEdge, height: CGFloat)
        case toast(corner: ToastCorner, size: CGSize)
        case custom(frame: CGRect)

        public enum BannerEdge {
            case top, bottom
        }

        public enum ToastCorner {
            case topLeft, topRight, bottomLeft, bottomRight
        }
    }

    // MARK: - Configuration
    public struct Configuration {
        let presentationMode: PresentationMode
        let position: WindowPosition?
        let width: CGFloat?
        let height: CGFloat?
        let windowLevel: WindowLevel
        let backgroundColor: NSColor
        let isTransparent: Bool
        let ignoresMouseEvents: Bool
        let isMoveable: Bool
        let alwaysOnTop: Bool
        let transparent: Bool
        let transparentMaterial: NSVisualEffectView.Material
        let windowOpacity: CGFloat
        let screenBlur: Bool
        let screenBlurMaterial: NSVisualEffectView.Material
        let dismissOnScreenTap: Bool
        let animatePresentation: Bool
        let screen: NSScreen?

        public init(
            presentationMode: PresentationMode = .fullScreen,
            position: WindowPosition? = nil,
            width: CGFloat? = nil,
            height: CGFloat? = nil,
            windowLevel: WindowLevel = .floating,
            backgroundColor: NSColor = .clear,
            isTransparent: Bool = true,
            ignoresMouseEvents: Bool = false,
            isMoveable: Bool = false,
            alwaysOnTop: Bool = true,
            transparent: Bool = false,
            transparentMaterial: NSVisualEffectView.Material = .hudWindow,
            windowOpacity: CGFloat = 1.0,
            screenBlur: Bool = false,
            screenBlurMaterial: NSVisualEffectView.Material = .underWindowBackground,
            dismissOnScreenTap: Bool = false,
            animatePresentation: Bool = true,
            screen: NSScreen? = nil
        ) {
            self.presentationMode = presentationMode
            self.position = position
            self.width = width
            self.height = height
            self.windowLevel = windowLevel
            self.backgroundColor = backgroundColor
            self.isTransparent = isTransparent
            self.ignoresMouseEvents = ignoresMouseEvents
            self.isMoveable = isMoveable
            self.alwaysOnTop = alwaysOnTop
            self.transparent = transparent
            self.transparentMaterial = transparentMaterial
            self.windowOpacity = windowOpacity
            self.screenBlur = screenBlur
            self.screenBlurMaterial = screenBlurMaterial
            self.dismissOnScreenTap = dismissOnScreenTap
            self.animatePresentation = animatePresentation
            self.screen = screen
        }
    }

    // MARK: - Private Init
    private init() {}

    // MARK: - Public Methods

    /// Show a SwiftUI view as an overlay window
    @discardableResult
    public func show<Content: View>(
        id: UUID = UUID(),
        configuration: Configuration = Configuration(),
        @ViewBuilder content: () -> Content
    ) -> UUID {
        // Create blur background window if needed
        if configuration.screenBlur {
            let blurWindow = createBlurWindow(configuration: configuration, notificationId: id)
            blurWindows[id] = blurWindow

            if configuration.animatePresentation {
                animateShow(window: blurWindow)
            } else {
                blurWindow.makeKeyAndOrderFront(nil)
            }
        }

        // Create main notification window
        let window = createWindow(configuration: configuration)
        let hostingView = NSHostingView(rootView: content())

        window.contentView = hostingView

        // Set up ESC key handler to dismiss the notification
        window.onEscapePressed = { [weak self] in
            self?.dismiss(id: id, animated: true)
        }

        // Store window reference
        activeWindows[id] = window

        // Animate if needed
        if configuration.animatePresentation {
            animateShow(window: window, targetOpacity: configuration.windowOpacity)
        } else {
            window.makeKeyAndOrderFront(nil)
        }

        return id
    }

    /// Dismiss a specific overlay window
    public func dismiss(id: UUID, animated: Bool = true) {
        guard let window = activeWindows[id] else { return }

        // Dismiss blur window if it exists
        if let blurWindow = blurWindows[id] {
            if animated {
                animateDismiss(window: blurWindow) { [weak self] in
                    self?.blurWindows.removeValue(forKey: id)
                }
            } else {
                blurWindow.close()
                blurWindows.removeValue(forKey: id)
            }
        }

        // Dismiss main window
        if animated {
            animateDismiss(window: window) { [weak self] in
                self?.activeWindows.removeValue(forKey: id)
            }
        } else {
            window.close()
            activeWindows.removeValue(forKey: id)
        }
    }

    /// Dismiss all overlay windows
    public func dismissAll(animated: Bool = true) {
        let ids = Array(activeWindows.keys)
        ids.forEach { dismiss(id: $0, animated: animated) }
    }

    // MARK: - Private Methods

    private func createWindow(configuration: Configuration) -> DismissibleWindow {
        let screen = configuration.screen ?? NSScreen.main ?? NSScreen.screens.first!
        var frame = calculateFrame(for: configuration.presentationMode, on: screen)

        // Apply custom width/height if provided
        if let width = configuration.width {
            frame.size.width = width
        }
        if let height = configuration.height {
            frame.size.height = height
        }

        // Apply position if provided (overrides presentation mode positioning)
        if let position = configuration.position {
            frame = calculateFrameForPosition(position, size: frame.size, on: screen)
        }

        let window = DismissibleWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isOpaque = !configuration.isTransparent
        window.backgroundColor = configuration.backgroundColor
        window.level = configuration.alwaysOnTop ? .floating : configuration.windowLevel.nsWindowLevel
        window.ignoresMouseEvents = configuration.ignoresMouseEvents
        window.isMovableByWindowBackground = configuration.isMoveable
        window.alphaValue = configuration.windowOpacity
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        return window
    }

    private func createBlurWindow(configuration: Configuration, notificationId: UUID) -> NSWindow {
        let screen = configuration.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame

        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        // Blur window should be below notification window but above everything else
        window.level = configuration.alwaysOnTop ? NSWindow.Level(rawValue: Int(NSWindow.Level.floating.rawValue) - 1) : configuration.windowLevel.nsWindowLevel
        window.ignoresMouseEvents = !configuration.dismissOnScreenTap
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Create blur view
        let blurView = NSHostingView(rootView: FullScreenBlurView(
            material: configuration.screenBlurMaterial,
            onTap: configuration.dismissOnScreenTap ? { [weak self] in
                self?.dismiss(id: notificationId)
            } : nil
        ))

        window.contentView = blurView

        return window
    }

    private func calculateFrame(for mode: PresentationMode, on screen: NSScreen) -> CGRect {
        let screenFrame = screen.frame

        switch mode {
        case .fullScreen:
            return screenFrame

        case .banner(let edge, let height):
            let y = edge == .top ? screenFrame.maxY - height : screenFrame.minY
            return CGRect(
                x: screenFrame.minX,
                y: y,
                width: screenFrame.width,
                height: height
            )

        case .toast(let corner, let size):
            let padding: CGFloat = 20
            let x: CGFloat
            let y: CGFloat

            switch corner {
            case .topLeft:
                x = screenFrame.minX + padding
                y = screenFrame.maxY - size.height - padding
            case .topRight:
                x = screenFrame.maxX - size.width - padding
                y = screenFrame.maxY - size.height - padding
            case .bottomLeft:
                x = screenFrame.minX + padding
                y = screenFrame.minY + padding
            case .bottomRight:
                x = screenFrame.maxX - size.width - padding
                y = screenFrame.minY + padding
            }

            return CGRect(x: x, y: y, width: size.width, height: size.height)

        case .custom(let frame):
            return frame
        }
    }

    private func calculateFrameForPosition(_ position: WindowPosition, size: CGSize, on screen: NSScreen) -> CGRect {
        let screenFrame = screen.frame
        let padding: CGFloat = 20
        let x: CGFloat
        let y: CGFloat

        switch position {
        case .topLeft:
            x = screenFrame.minX + padding
            y = screenFrame.maxY - size.height - padding
        case .top:
            x = screenFrame.minX + (screenFrame.width - size.width) / 2
            y = screenFrame.maxY - size.height - padding
        case .topRight:
            x = screenFrame.maxX - size.width - padding
            y = screenFrame.maxY - size.height - padding
        case .left:
            x = screenFrame.minX + padding
            y = screenFrame.minY + (screenFrame.height - size.height) / 2
        case .center:
            x = screenFrame.minX + (screenFrame.width - size.width) / 2
            y = screenFrame.minY + (screenFrame.height - size.height) / 2
        case .right:
            x = screenFrame.maxX - size.width - padding
            y = screenFrame.minY + (screenFrame.height - size.height) / 2
        case .bottomLeft:
            x = screenFrame.minX + padding
            y = screenFrame.minY + padding
        case .bottom:
            x = screenFrame.minX + (screenFrame.width - size.width) / 2
            y = screenFrame.minY + padding
        case .bottomRight:
            x = screenFrame.maxX - size.width - padding
            y = screenFrame.minY + padding
        }

        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func animateShow(window: NSWindow, targetOpacity: CGFloat = 1.0) {
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = targetOpacity
        }
    }

    private func animateDismiss(window: NSWindow, completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            window.close()
            completion()
        })
    }
}
