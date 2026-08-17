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

  /// Internal, not private, and read by `LegibilityTests` — a wiring assertion
  /// in the same spirit as `NotificationClock.isRunning`. `Legibility` can be
  /// perfectly correct while this view ignores it, and a suite that only tests
  /// the pure functions cannot tell the difference.
  var scrimStrategy: ScrimStrategy {
    Legibility.scrimStrategy(
      effectiveDim: effectiveDim, reduceTransparency: reducesTransparency)
  }

  /// The colour scheme is passed to make the call site honest and is discarded
  /// inside: both scrims are dark, so both modes render light text in both
  /// system themes.
  var styles:
    (title: Legibility.TextStyle, message: Legibility.TextStyle, footnote: Legibility.TextStyle)
  {
    Legibility.textStyles(colorScheme: .dark)
  }

  /// The task ring's timer, or `nil` if no ring is drawn. Internal and read by
  /// the body, so it cannot drift from what is on screen.
  var resolvedTaskTimer: TaskTimer? { notification.effectiveTaskTimer }

  /// Whether the dismiss indicator child is drawn at all. **Independent of
  /// `resolvedTaskTimer`** — the two are sequential phases, not alternatives.
  /// Whether it draws anything *right now* is the pure function's call, not
  /// this one's.
  var drawsDismissIndicator: Bool { notification.autoDismiss != nil }

  // MARK: - Body

  public var body: some View {
    // The `GeometryReader` is doing two jobs, both load-bearing.
    //
    // **One: it stops this view resizing the window it is hosted in.**
    // `OverlayWindowManager.createWindow` builds a borderless `NSWindow` at a
    // caller-chosen frame and installs an `NSHostingView` as its `contentView`.
    // That hosting view publishes an `intrinsicContentSize` derived from the
    // SwiftUI content, and AppKit resolves the resulting constraint by resizing
    // *the window* — one run-loop pass after `show()` returns, which is why the
    // frame is still correct when `show()` hands back. Measured through the
    // public API before this existed:
    //
    //   .ambient, long message       (1328, 20, 380, 210) -> (1328, -2059, 380, 2289)
    //   .ambient, 600x500 image      (1328, 20, 380, 210) -> (1328,  -358, 656,  588)
    //   .interrupt, long message     the screen, 1728x1117 -> (0, -27049, 1728, 28166)
    //
    // Note the third row: the intuitive reading — "only fixed-size ambient
    // windows are affected, interrupt asks for the whole screen anyway" — is
    // wrong. Interrupt blew up by a factor of twenty-five, invisibly, because
    // the window is transparent; it just centred the content thousands of
    // points off-screen. Any fix scoped to `.ambient` would have left that in.
    //
    // A `GeometryReader` is the lever because it is greedy and incurious: it
    // accepts whatever size it is proposed and never reports its children's
    // requirements upward, so the hosting view stops having an opinion about
    // how big the window should be.
    //
    // **Two: it hands the content the size it must fit into**, which is what
    // lets an oversized illustration scale down instead of evicting everything
    // else. See `Illustration.fitted(in:)`.
    GeometryReader { proxy in
      body(in: proxy.size)
        .frame(width: proxy.size.width, height: proxy.size.height)
    }
    // Content that still does not fit is cut off rather than granted a bigger
    // window. With the illustration bounded above, what gets cut is the tail of
    // a long message — not, as it once was, the entire alert.
    .clipped()
    .onAppear(perform: enter)
  }

  private func body(in available: CGSize) -> some View {
    ZStack {
      // `.interrupt` under Reduce Transparency: the backdrop window's blur is
      // dropped, and this is the opaque black that replaces it. Drawn in the
      // content window because `Configuration.screenDim` clamps at 0.95 —
      // "solid" has to be genuinely solid, and here it is.
      if notification.mode == .interrupt, reducesTransparency {
        Color.black.bleedingToScreenEdges(bleeds)
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
        .bleedingToScreenEdges(bleeds)

      content(in: available)
        .scaleEffect(entranceScale)
        .opacity(entranceOpacity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Whether this alert's window *is* the screen.
  ///
  /// `.interrupt` is presented full-screen with `width`/`height` left `nil`, so
  /// bleeding past the safe area is exactly right — the scrim must reach the
  /// menu bar and the notch, not stop short of them. `.ambient` is a fixed-size
  /// window the caller sized, where there is no screen edge to reach and
  /// nothing to gain.
  private var bleeds: Bool { notification.mode == .interrupt }

  private func content(in available: CGSize) -> some View {
    VStack(spacing: 22) {
      illustration(in: available)

      // Title and message share one scrim: they are one text block, and two
      // adjacent gradients would meet in a seam that reads as an edge.
      if notification.title != nil || notification.message != nil {
        VStack(spacing: 10) {
          if let title = notification.title {
            styled(Text(title).font(.system(size: 26, weight: .semibold)), as: styles.title)
          }
          if let message = notification.message {
            // Refuses vertical truncation, so a long message wraps in full
            // instead of being clipped to one line by a tight parent.
            //
            // Safe *because* of the `GeometryReader` in `body`, and not before
            // it: this modifier makes height a required function of width, and
            // that requirement used to propagate out and resize the window.
            styled(Text(message).font(.system(size: 15)), as: styles.message)
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
        styled(Text(footnote).font(.system(size: 12)), as: styles.footnote)
          // Its own scrim rather than a share of the block's: the footnote sits
          // below the buttons, and one rect spanning both would put a gradient
          // behind buttons that already carry their own contrast.
          .scrimmed(scrimStrategy, feather: 28)
      }
    }
    .padding(28)
  }

  /// The **only** place this renderer sets a text colour or a text shadow.
  ///
  /// Funnelling all of it through one function is not tidiness. Colour and
  /// shadow chosen per call site is exactly the shape the original bug had —
  /// four independent `.foregroundColor`/`.shadow` pairs, one of which was
  /// `.clear` and another a white glow under white text — and it is
  /// unassertable when it is spread out. With one funnel, `LegibilityTests`
  /// can render this view and check the pixels that come out, and any attempt
  /// to reintroduce a per-site colour has to visibly route around this.
  private func styled(_ text: Text, as style: Legibility.TextStyle) -> some View {
    text
      .foregroundColor(style.color)
      .shadow(color: style.shadowColor, radius: style.shadowRadius, y: style.shadowOffsetY)
      .multilineTextAlignment(.center)
  }

  // MARK: - Illustration

  @ViewBuilder
  private func illustration(in available: CGSize) -> some View {
    if let illustration = notification.illustration {
      // Bounded against the space actually available. Unbounded, a large
      // caller-supplied image pushed every other element outside the clip and
      // the alert rendered completely blank.
      illustrationBody(illustration.fitted(in: available))
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
      VStack(spacing: 14) {
        // `resolvedTaskTimer` reads `effectiveTaskTimer`, not `taskTimer`:
        // `.ambient` gets the dismiss indicator only, and that rule is enforced
        // on the model so the clock and the renderer cannot disagree about
        // whether a task is running.
        if let timer = resolvedTaskTimer {
          CountdownRing(
            clock: clock,
            notification: notification,
            timer: timer,
            completedEarly: completedEarly,
            reduceMotion: reducesMotion)
        }

        // Deliberately *not* an `else`. A task timer and an auto-dismiss are
        // sequential phases, not alternatives: the task runs first and alone,
        // and the dismiss indicator has to be reachable once it hands over —
        // "then the dismiss phase runs, its indicator visible if one was
        // configured". Choosing the child structurally made that unreachable
        // for the flagship 20s-task-plus-5s-dismiss case, and turned
        // `dismissIndicator(in:)`'s `.dismissing` branch into dead code that a
        // green test still claimed to cover. Suppression during `.task` is the
        // pure function's job; this view draws `EmptyView` for `.none`.
        if drawsDismissIndicator {
          DismissIndicatorView(
            clock: clock, notification: notification, reduceMotion: reducesMotion)
        }
      }
      // Without this the countdown is light-on-nothing in `.ambient`. The
      // ring's numerals carry opposing shadows, but a shadow is a second-order
      // safety net and was never the contrast mechanism — and the dismiss bar
      // had neither. Scrimmed like the text block, which is what the invariant
      // requires of anything this library draws light.
      .scrimmed(scrimStrategy, feather: 32)
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

// MARK: - Window geometry

extension View {
  /// `ignoresSafeArea()`, but only where a safe area is something this alert has
  /// any business crossing.
  ///
  /// `.interrupt` owns the whole screen and its backdrop must reach the menu bar
  /// and the notch rather than stopping short of them. `.ambient` is a
  /// fixed-size window the caller positioned, where there is no screen edge to
  /// reach.
  ///
  /// Recorded because the first diagnosis of the window-resizing defect blamed
  /// this modifier: it is **not** the cause, and removing it outright changed
  /// nothing (verified — the ambient window still settled at
  /// `(1328, -2059, 380, 2289)` with both calls deleted). The `GeometryReader`
  /// in `body` is the actual fix. This stays conditional on its own smaller
  /// merits: unconditionally it was stating an intent true for only one mode.
  @ViewBuilder
  func bleedingToScreenEdges(_ bleeds: Bool) -> some View {
    if bleeds {
      ignoresSafeArea()
    } else {
      self
    }
  }
}
