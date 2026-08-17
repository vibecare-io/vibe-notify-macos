import AppKit
import SVGView
import SwiftUI

/// The third renderer, added beside `StandardNotificationView` and
/// `SVGNotificationView`. Neither of those changes, and neither existing model
/// changes.
///
/// It draws, top to bottom: illustration, title, message, the task ring (or the
/// quiet dismiss indicator), the button row, the footnote. No card, no panel,
/// no border, no container shadow — there is no container. Content sits
/// directly on the scrim.
///
/// **The legibility invariant it serves:** text is never rendered over a
/// backdrop whose luminance this view does not control. `.interrupt` inherits a
/// global scrim from its blur window's 0.55 dim; `.ambient` draws a local
/// feathered scrim under its own text. Text colour then follows the scrim *we
/// drew*, never `@Environment(\.colorScheme)` — `useLightText = (colorScheme ==
/// .dark)` in `SVGNotificationView` is precisely the defect being fixed, and
/// nothing in this file reads the colour scheme.
public struct RichNotificationView: View {

  private let notification: RichNotification
  private let onDismiss: () -> Void
  private let effectiveDimOverride: Double?
  private let reduceMotionOverride: Bool?
  private let reduceTransparencyOverride: Bool?

  /// The reference only — **not** a subscription. `NotificationClock` is a
  /// Combine `ObservableObject`, so this hands back the same object for the
  /// life of the overlay and never invalidates this body. That is exactly what
  /// is wanted here: a per-tick invalidation of *this* view would re-parse
  /// `SVGView` ten times a second. Anything that draws the countdown is handed
  /// the reference and observes it itself (`CountdownRing`,
  /// `DismissIndicatorView`).
  @Environment(\.notificationClock) private var clock

  /// Entrance state. Skipped entirely under Reduce Motion, where content is
  /// placed at final scale rather than animated to it.
  @State private var entranceScale: CGFloat = 0.92
  @State private var entranceOpacity: Double = 0.0

  /// Set when Done is pressed while the task is still counting. The clock
  /// records *that* the task ended on its own terms (`didCompleteTask`) but not
  /// *how*, and the difference is the whole honesty rule — so the view, which
  /// is where the press happens, carries it.
  @State private var completedEarly: Bool = false

  /// - Parameters:
  ///   - effectiveDim: the dim of whatever backdrop is already in place, which
  ///     is what selects between the scrim strategies. Not a `Bool` over
  ///     "is blur on": a `.light` blur at the pinned 0.1 is blur-on and is not
  ///     a safe backdrop. Defaults to what the mode implies.
  ///   - reduceMotion/reduceTransparency: overrides for the live system
  ///     settings, so the demo harness and tests can drive both branches.
  public init(
    notification: RichNotification,
    effectiveDim: Double? = nil,
    reduceMotion: Bool? = nil,
    reduceTransparency: Bool? = nil,
    onDismiss: @escaping () -> Void
  ) {
    self.notification = notification
    self.effectiveDimOverride = effectiveDim
    self.reduceMotionOverride = reduceMotion
    self.reduceTransparencyOverride = reduceTransparency
    self.onDismiss = onDismiss
  }

  // MARK: - Resolved inputs

  private var reducesMotion: Bool {
    reduceMotionOverride ?? Legibility.Accessibility.reduceMotion
  }

  private var reducesTransparency: Bool {
    reduceTransparencyOverride ?? Legibility.Accessibility.reduceTransparency
  }

  private var effectiveDim: Double {
    if let effectiveDimOverride { return effectiveDimOverride }
    return Legibility.backdrop(for: notification.mode, reduceTransparency: reducesTransparency)?
      .effectiveDim ?? 0
  }

  private var scrimStrategy: ScrimStrategy {
    Legibility.scrimStrategy(
      effectiveDim: effectiveDim, reduceTransparency: reducesTransparency)
  }

  /// The colour scheme is passed to make the call site honest and is discarded
  /// inside: both scrims are dark, so both modes render light text in both
  /// system themes.
  private var styles: (title: Legibility.TextStyle, message: Legibility.TextStyle, footnote: Legibility.TextStyle) {
    Legibility.textStyles(mode: notification.mode, colorScheme: .dark)
  }

  // MARK: - Body

  public var body: some View {
    ZStack {
      // `.interrupt` under Reduce Transparency: the backdrop window's blur is
      // dropped, and this is the opaque black that replaces it. Drawn in the
      // content window because `Configuration.screenDim` clamps at 0.95 —
      // "solid" has to be genuinely solid, and here it is.
      if notification.mode == .interrupt, reducesTransparency {
        Color.black.ignoresSafeArea()
      }

      // The full-bleed dismissal target, *below* the content so the buttons
      // take their taps first. `.interrupt` needs its own because
      // `dismissOnScreenTap` installs its handler on the blur window, which is
      // levelled below the content window — with a full-screen content window
      // the blur window is completely occluded and receives nothing, so
      // click-anywhere silently does not work. That is a defect to fix, not
      // inherit. In `.ambient` the window is sized to its content, so the same
      // target is simply "a click on the alert itself".
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture { dismissByCancelling() }
        .ignoresSafeArea()

      content
        .scaleEffect(entranceScale)
        .opacity(entranceOpacity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear(perform: enter)
  }

  private var content: some View {
    VStack(spacing: 22) {
      illustration

      // Title and message share one scrim: they are one text block, and two
      // adjacent gradients would meet in a seam that reads as an edge.
      if notification.title != nil || notification.message != nil {
        VStack(spacing: 10) {
          if let title = notification.title {
            Text(title)
              .font(.system(size: 26, weight: .semibold))
              .foregroundColor(styles.title.color)
              .shadow(
                color: styles.title.shadowColor,
                radius: styles.title.shadowRadius,
                y: styles.title.shadowOffsetY)
              .multilineTextAlignment(.center)
          }
          if let message = notification.message {
            Text(message)
              .font(.system(size: 15))
              .foregroundColor(styles.message.color)
              .shadow(
                color: styles.message.shadowColor,
                radius: styles.message.shadowRadius,
                y: styles.message.shadowOffsetY)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: 460)
        .scrimmed(scrimStrategy)
      }

      countdown

      if !notification.buttons.isEmpty {
        HStack(spacing: 12) {
          ForEach(notification.buttons) { button in
            SwiftUI.Button(action: { press(button) }) {
              Text(button.title)
            }
            .buttonStyle(RichButtonStyle(role: button.style))
          }
        }
      }

      if let footnote = notification.footnote {
        Text(footnote)
          .font(.system(size: 12))
          .foregroundColor(styles.footnote.color)
          .shadow(
            color: styles.footnote.shadowColor,
            radius: styles.footnote.shadowRadius,
            y: styles.footnote.shadowOffsetY)
          .multilineTextAlignment(.center)
          // Its own scrim rather than a share of the block's: the footnote sits
          // below the buttons, and one rect spanning both would put a gradient
          // behind buttons that already carry their own contrast.
          .scrimmed(scrimStrategy, feather: 28)
      }
    }
    .padding(28)
  }

  // MARK: - Illustration

  @ViewBuilder
  private var illustration: some View {
    if let illustration = notification.illustration {
      illustrationBody(illustration)
        // A dark drop shadow, never a glow. The existing SVG renderer applies a
        // coloured glow in dark mode, which reinforces the illustration against
        // dark backdrops and erases it against light ones — the same mistake as
        // the white halo under white text.
        .shadow(color: .black.opacity(0.5), radius: 15, y: 2)
    }
  }

  @ViewBuilder
  private func illustrationBody(_ illustration: RichNotification.Illustration) -> some View {
    switch illustration {
    case .svg(let source, let size):
      SVGView(contentsOf: source.url)
        .frame(width: size.width, height: size.height)
    case .image(let image, let size):
      Image(nsImage: image)
        .resizable()
        .scaledToFit()
        .frame(width: size.width, height: size.height)
    case .symbol(let name, let pointSize, let color):
      Image(systemName: name)
        .font(.system(size: pointSize))
        // Defaults to the title colour, not `.primary`: this is the fallback an
        // unconfigured schedule alert gets, and it must be legible over the
        // scrim like everything else.
        .foregroundColor(color ?? styles.title.color)
    }
  }

  // MARK: - Countdown

  /// Both branches hand the clock *reference* to a child that holds it as
  /// `@ObservedObject`. That indirection is the documented pattern and the
  /// reason this view can read `@Environment(\.notificationClock)` without
  /// being invalidated on every tick.
  @ViewBuilder
  private var countdown: some View {
    if let clock {
      if let timer = notification.taskTimer {
        CountdownRing(
          clock: clock,
          notification: notification,
          timer: timer,
          completedEarly: completedEarly,
          reduceMotion: reducesMotion)
      } else {
        // Rendered unconditionally: which indicator applies depends on the
        // phase, so the decision belongs on the observing side. The view draws
        // `EmptyView` for `.none`.
        DismissIndicatorView(
          clock: clock, notification: notification, reduceMotion: reducesMotion)
      }
    }
  }

  // MARK: - Entrance

  private func enter() {
    guard !reducesMotion else {
      // Content at final scale, no spring. The countdown is the deliberate
      // exception to Reduce Motion and keeps running — it is information being
      // read, not decoration — which is why this only governs the entrance.
      entranceScale = 1.0
      entranceOpacity = 1.0
      return
    }
    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
      entranceScale = 1.0
      entranceOpacity = 1.0
    }
  }

  // MARK: - Dismissal

  /// ESC is wired by the window; this is the click-away half. Cancellation
  /// produces no completion state and no acknowledgement.
  private func dismissByCancelling() {
    clock?.cancel()
    onDismiss()
  }

  /// The caller's closure supplies the *meaning*; the library guarantees what
  /// happens to the clock and the window around it. Every route ends with the
  /// window down — one of them via the clock, which is the only way an
  /// acknowledgement can be on screen long enough to read. See
  /// `RichNotification.outcome(for:taskPhaseActive:hasClock:)`.
  private func press(_ button: StandardNotification.Button) {
    let outcome = RichNotification.outcome(
      for: button.style,
      taskPhaseActive: clock?.phase == .task,
      hasClock: clock != nil)

    switch outcome {
    case .completeTaskThenHold:
      completedEarly = true
      clock?.completeTask()
      button.action()
    case .cancelAndDismiss:
      clock?.cancel()
      button.action()
      onDismiss()
    case .dismiss:
      button.action()
      onDismiss()
    }
  }
}
