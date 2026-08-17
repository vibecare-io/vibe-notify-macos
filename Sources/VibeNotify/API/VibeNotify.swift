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
    ///
    /// Deprecated rather than asserting: an `assertionFailure` compiles away
    /// in release builds, which would silently resume swallowing a caller's
    /// `buttons:` — this type has none — exactly the defect `RichNotification`
    /// exists to fix. `.svg(...).button(...)` through the builder now routes
    /// to the rich renderer instead of reaching this at all.
    @available(*, deprecated, message: "Use RichNotification and VibeNotify.showRich(_:configuration:) — SVGNotification cannot express buttons or a footnote.")
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
    @available(*, deprecated, message: "Use RichNotification and VibeNotify.showRich(_:configuration:) — SVGNotification cannot express buttons or a footnote.")
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

    // MARK: - Rich Notifications

    /// Show a `RichNotification` — illustration, footnote, task timer and
    /// buttons together, none of which `show()`/`showSVG` can express in
    /// combination.
    ///
    /// This is the entry point that was missing before this method existed:
    /// every call site that wanted the rich renderer, including this
    /// library's own demo harness and its tests, had to reach past this
    /// class and call `OverlayWindowManager.show(id:configuration:countdown:content:)`
    /// directly. `configuration` should come from `OverlayWindowManager.Configuration.interrupt(...)`
    /// or `.ambient(...)`, matching `notification.mode` — the two are meant
    /// to travel together (see `AlertMode`'s doc comment); passing a
    /// configuration for one mode with a notification set to the other
    /// produces a backdrop that disagrees with what the renderer assumes is
    /// already behind it.
    ///
    /// - Parameters:
    ///   - reduceMotion/reduceTransparency: overrides for the live
    ///     `NSWorkspace` accessibility settings, forwarded to
    ///     `RichNotificationView`. `nil` (the default) reads the system value.
    ///   - onEnd: called exactly once, whenever this overlay closes — a
    ///     button, ESC, a click away, `dismiss(id:)`, or the countdown
    ///     reaching its own end. That last case has no other signal: a clock
    ///     that reaches its deadline tears the window down through
    ///     `OverlayWindowManager.clockDidEnd`, which never runs the
    ///     `onDismiss` closure baked into the hosted view, so a caller with
    ///     no other way to observe "this overlay closed itself" had none at
    ///     all — precisely what broke the demo harness's own active-alert
    ///     counter. The `NotificationClock.Phase` handed back is whatever the
    ///     clock's phase was at the moment of closing (`.finished` for a
    ///     countdown that ran out on its own, `.cancelled` for everything
    ///     else that ends it early) — `nil` when there was no clock at all,
    ///     i.e. `notification.countdown == nil`.
    @discardableResult
    public func showRich(
        _ notification: RichNotification,
        configuration: OverlayWindowManager.Configuration,
        reduceMotion: Bool? = nil,
        reduceTransparency: Bool? = nil,
        onEnd: ((NotificationClock.Phase?) -> Void)? = nil
    ) -> UUID {
        let id = UUID()

        // Closes the gap this fix targets: `RichNotificationView` already
        // draws an opaque black layer under Reduce Transparency
        // (`notification.mode == .interrupt, reducesTransparency`), so a
        // blurred, 0.55-dimmed blur window built *behind* it is a live,
        // invisible no-op — correct pixels for the wrong reason, and nothing
        // will ever prompt anyone to notice. `Legibility.backdrop` is the
        // same function the renderer itself consults, so the two cannot
        // disagree about when the blur window should exist at all.
        let resolvedReduceTransparency =
            reduceTransparency ?? Legibility.Accessibility.reduceTransparency
        let backdrop = Legibility.backdrop(
            for: notification.mode, reduceTransparency: resolvedReduceTransparency)
        let effectiveConfiguration =
            backdrop == .opaque ? Self.suppressingBlur(configuration) : configuration

        windowManager.show(
            id: id,
            configuration: effectiveConfiguration,
            countdown: notification.countdown,
            onEnd: { [weak self] endedID, phase in
                self?.activeNotificationIDs.removeAll { $0 == endedID }
                onEnd?(phase)
            }
        ) { [weak self] in
            RichNotificationView(
                notification: notification,
                reduceMotion: reduceMotion,
                reduceTransparency: reduceTransparency
            ) {
                self?.dismiss(id: id)
            }
        }

        activeNotificationIDs.append(id)
        return id
    }

    /// `configuration` with `screenBlur` forced off and every other field
    /// carried through unchanged. `Configuration`'s own initializer, not a
    /// bespoke copy helper — its parameter list is the one this codebase
    /// treats as a frozen contract, so building through it here means this
    /// stays correct automatically if a field is ever added to it.
    ///
    /// Internal, not private: `RoutingTests` asserts on the *derived
    /// configuration* this produces, not only on `Legibility.Backdrop`'s
    /// `.opaque` case — `Legibility` being correct is worth nothing if
    /// `showRich` computes its own answer about whether to call it.
    static func suppressingBlur(
        _ configuration: OverlayWindowManager.Configuration
    ) -> OverlayWindowManager.Configuration {
        OverlayWindowManager.Configuration(
            presentationMode: configuration.presentationMode,
            position: configuration.position,
            width: configuration.width,
            height: configuration.height,
            windowLevel: configuration.windowLevel,
            backgroundColor: configuration.backgroundColor,
            isTransparent: configuration.isTransparent,
            ignoresMouseEvents: configuration.ignoresMouseEvents,
            isMoveable: configuration.isMoveable,
            alwaysOnTop: configuration.alwaysOnTop,
            transparent: configuration.transparent,
            transparentMaterial: configuration.transparentMaterial,
            windowOpacity: configuration.windowOpacity,
            screenBlur: false,
            screenBlurMaterial: configuration.screenBlurMaterial,
            screenBlurIntensity: configuration.screenBlurIntensity,
            dismissOnScreenTap: configuration.dismissOnScreenTap,
            animatePresentation: configuration.animatePresentation,
            screen: configuration.screen,
            screenDim: configuration.screenDim,
            takesKeyFocus: configuration.takesKeyFocus
        )
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

    // Rich mode — see `routesToRichRenderer` for how these, together with
    // `illustration`/`svg`/`buttons` above, decide which renderer `show()`
    // hands off to.
    private var richIllustration: RichNotification.Illustration?
    private var footnote: String?
    private var taskTimer: TaskTimer?
    private var mode: AlertMode = .ambient
    /// Set only by `mode(_:)`, never by the stored `mode`'s default. This is
    /// what lets `taskTimerUpgradingModeIfNeeded()` tell "the caller left
    /// mode unset" apart from "the caller explicitly asked for `.ambient`" —
    /// the two must not be treated the same, see that function's doc comment.
    private var modeExplicitlySet: Bool = false

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

    /// Deprecated alongside `AutoDismiss.init(delay:showProgress:)` (see
    /// `NotificationContent.swift`) — kept, not replaced with an
    /// `indicator:`-taking overload, because a second defaulted-second-
    /// parameter overload of the same base name would make every existing
    /// call site that omits both trailing arguments ambiguous. Building a
    /// non-ambiguous `indicator:` entry point onto the builder is engine
    /// work for the next task, not this one.
    @available(*, deprecated, message: "showProgress: true maps to AutoDismiss.indicator == .bar, false maps to .none")
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

    // MARK: - Rich builder methods

    /// An illustration the plain `.svg(...)`/`.svgURL(...)` pair cannot
    /// express: a bitmap already fetched by the caller (`.image`) or an SF
    /// Symbol (`.symbol`). Setting this, on its own, is enough to route to
    /// the rich renderer — see `routesToRichRenderer`.
    public func illustration(_ illustration: RichNotification.Illustration) -> Self {
        self.richIllustration = illustration
        return self
    }

    /// A fifth text slot the rich renderer draws below the buttons —
    /// `RichNotification`'s own doc comment covers why it is a separate
    /// property from `message`.
    public func footnote(_ footnote: String) -> Self {
        self.footnote = footnote
        return self
    }

    /// The large, legible countdown ring. See `taskTimerUpgradingModeIfNeeded()`
    /// for what happens when this is set without a matching `.mode(.interrupt)`.
    public func taskTimer(_ timer: TaskTimer) -> Self {
        self.taskTimer = timer
        return self
    }

    /// Opts into the rich renderer's presentation intent. Setting this at
    /// all — including to `.ambient`, the same value it already defaults to —
    /// is a rich-only signal on its own (rule 1 of `routesToRichRenderer`):
    /// it is how `.svg(path).show()` keeps rendering exactly as it did in
    /// 0.0.5 while `.svg(path).mode(.ambient).show()` opts into the new
    /// renderer for a caller who wants it on purpose.
    public func mode(_ mode: AlertMode) -> Self {
        self.mode = mode
        self.modeExplicitlySet = true
        return self
    }

    // MARK: - Routing

    /// Whether `show()` hands this builder's state to the rich renderer.
    ///
    /// Rule 1: any field the *old* renderers cannot express at all — `mode`
    /// explicitly set, a task timer, a footnote, or an illustration kind
    /// (`.image`/`.symbol`) `SVGNotificationView` cannot draw — routes rich
    /// outright, regardless of buttons. Rule 2: short of that, an
    /// illustration of *any* kind (including a plain `.svg`) combined with at
    /// least one button also routes rich — this is the fix for the silent
    /// button drop: `.svg(path).button(...).show()` used to compile and
    /// silently discard the button because `show()` forked on `useSVG` before
    /// buttons ever entered the picture. Short of both, `.svg(path).show()`
    /// alone renders exactly as it did in 0.0.5 — rule 1 existing is what
    /// makes that safe: a caller who wants the new renderer for an SVG-only
    /// alert opts in with one `.mode(...)` call rather than getting it
    /// silently forced on them.
    ///
    /// Internal, not private — `RoutingTests` asserts this directly so a
    /// regression in the decision itself is visible without inspecting a live
    /// window's hosted content view.
    var routesToRichRenderer: Bool {
        let hasRichOnlyField =
            modeExplicitlySet || taskTimer != nil || footnote != nil
            || isImageOrSymbolIllustration
        if hasRichOnlyField { return true }
        return resolvedIllustration != nil && !buttons.isEmpty
    }

    private var isImageOrSymbolIllustration: Bool {
        switch richIllustration {
        case .image, .symbol: return true
        case .svg, .none: return false
        }
    }

    /// The illustration `richNotification()` draws, preferring the explicit
    /// `.illustration(_:)` value and otherwise translating the legacy
    /// `.svg(...)`/`.svgURL(...)` fields into the same `Illustration.svg`
    /// case `RichNotificationView` already knows how to render.
    private var resolvedIllustration: RichNotification.Illustration? {
        if let richIllustration { return richIllustration }
        guard useSVG else { return nil }
        if let svgURL { return .svg(.url(svgURL), size: svgSize) }
        if let svgPath { return .svg(.filePath(svgPath), size: svgSize) }
        return nil
    }

    /// `mode`, upgraded to `.interrupt` when the caller set a task timer but
    /// never called `.mode(...)` at all.
    ///
    /// `RichNotification.effectiveTaskTimer` already enforces — deliberately,
    /// and covered by `LegibilityTests` — that `.ambient` never draws a task
    /// ring: a labelled ring reads as a task, and ambient alerts have none.
    /// That rule is correct at the model layer, where `.ambient` is always
    /// what the caller actually asked for. Through the builder it is not: the
    /// stored `mode` defaults to `.ambient` whether or not the caller ever
    /// thought about it, so `.taskTimer(TaskTimer(duration: 20, ...))` alone
    /// — the shape a caller reaches for when they want a ring — would
    /// silently produce neither a ring nor a clock, with no error and no
    /// visible alert to explain why.
    ///
    /// Upgrading was chosen over refusing loudly (a `fatalError` or
    /// `assertionFailure`) for the same reason `showSVG` is deprecated rather
    /// than asserted a few lines up this file: a crash that only exists in
    /// debug builds resumes the silent failure exactly where checking is
    /// cheapest to skip, and a `RichNotification` with a task timer is
    /// overwhelmingly more likely to be a caller who forgot `.mode(...)` than
    /// one who deliberately wants a ring nobody can see. A caller who really
    /// does want `.ambient` with a task timer already has the escape hatch:
    /// calling `.mode(.ambient)` explicitly sets `modeExplicitlySet`, which
    /// this reads and leaves alone.
    private var resolvedMode: AlertMode {
        (taskTimer != nil && !modeExplicitlySet) ? .interrupt : mode
    }

    /// The `RichNotification` `show()` would present, built the same way
    /// `show()` builds it. Internal, not private, so `RoutingTests` can
    /// assert on buttons/illustration/mode without inspecting a live window's
    /// hosted content — the same "read the decision, not the pixels" pattern
    /// `LegibilityTests` uses for the renderer itself.
    func richNotification() -> RichNotification {
        RichNotification(
            illustration: resolvedIllustration,
            title: title,
            message: message,
            footnote: footnote,
            buttons: buttons,
            taskTimer: taskTimer,
            autoDismiss: autoDismiss,
            mode: resolvedMode
        )
    }

    /// The `Configuration` `show()` hands `VibeNotify.showRich` alongside
    /// `richNotification()`, derived from `resolvedMode` via the same
    /// `AlertMode` factories `RichDemoPresenter` and every rich-renderer test
    /// use — never assembled by hand here. `AlertMode`'s own doc comment is
    /// the reason: it "bundles the ~20 `Configuration` knobs ... that are
    /// only ever correct together," and the legacy builder knobs this class
    /// already carries (`transparent`, `screenBlur`, `windowLevel`, a plain
    /// `windowOpacity`, ...) are exactly the set that produced the bug this
    /// whole task fixes when mixed by hand. `.ambient` requires a position
    /// and a size where `.interrupt` requires neither; short of a caller
    /// supplying them through the existing `.position(...)`/`.width(...)`/
    /// `.height(...)` builder methods, this falls back to the same corner and
    /// footprint `showSVG`'s own default `presentationMode` already used
    /// (`.toast(corner: .topRight, size: 300×400)`), so a caller who reaches
    /// for `.mode(.ambient)` without also repositioning things does not land
    /// somewhere new.
    private func richConfiguration() -> OverlayWindowManager.Configuration {
        switch resolvedMode {
        case .interrupt:
            return .interrupt(dismissOnScreenTap: dismissOnScreenTap)
        case .ambient:
            return .ambient(
                position: position ?? .topRight,
                width: width ?? 300,
                height: height ?? 400,
                dismissOnScreenTap: dismissOnScreenTap)
        }
    }

    @discardableResult
    public func show() -> UUID {
        if routesToRichRenderer {
            return VibeNotify.shared.showRich(richNotification(), configuration: richConfiguration())
        }

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
