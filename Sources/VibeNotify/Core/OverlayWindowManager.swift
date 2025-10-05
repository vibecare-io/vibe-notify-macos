import AppKit
import SwiftUI

/// Manages overlay windows for notifications with customizable presentation modes
@MainActor
public class OverlayWindowManager {

    // MARK: - Singleton
    public static let shared = OverlayWindowManager()

    // MARK: - Properties
    private var activeWindows: [UUID: NSWindow] = [:]

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
        let windowLevel: WindowLevel
        let backgroundColor: NSColor
        let isTransparent: Bool
        let ignoresMouseEvents: Bool
        let animatePresentation: Bool
        let screen: NSScreen?

        public init(
            presentationMode: PresentationMode = .fullScreen,
            windowLevel: WindowLevel = .floating,
            backgroundColor: NSColor = .clear,
            isTransparent: Bool = true,
            ignoresMouseEvents: Bool = false,
            animatePresentation: Bool = true,
            screen: NSScreen? = nil
        ) {
            self.presentationMode = presentationMode
            self.windowLevel = windowLevel
            self.backgroundColor = backgroundColor
            self.isTransparent = isTransparent
            self.ignoresMouseEvents = ignoresMouseEvents
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
        let window = createWindow(configuration: configuration)
        let hostingView = NSHostingView(rootView: content())

        window.contentView = hostingView

        // Store window reference
        activeWindows[id] = window

        // Animate if needed
        if configuration.animatePresentation {
            animateShow(window: window)
        } else {
            window.makeKeyAndOrderFront(nil)
        }

        return id
    }

    /// Dismiss a specific overlay window
    public func dismiss(id: UUID, animated: Bool = true) {
        guard let window = activeWindows[id] else { return }

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

    private func createWindow(configuration: Configuration) -> NSWindow {
        let screen = configuration.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let frame = calculateFrame(for: configuration.presentationMode, on: screen)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isOpaque = !configuration.isTransparent
        window.backgroundColor = configuration.backgroundColor
        window.level = configuration.windowLevel.nsWindowLevel
        window.ignoresMouseEvents = configuration.ignoresMouseEvents
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

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

    private func animateShow(window: NSWindow) {
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
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
