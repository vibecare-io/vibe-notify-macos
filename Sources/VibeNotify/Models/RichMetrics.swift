import CoreGraphics

/// Every type size and every vertical gap the rich renderer uses, in one place
/// and as a function of the mode.
///
/// **Why this is a type and not a pile of literals in the view body.** The
/// renderer had a single `VStack(spacing: 22)` doing all of the vertical
/// rhythm, which is the layout equivalent of a single alpha for every scrim: it
/// says *everything on this surface is equally related to everything else*. It
/// isn't. A title and its message are one object; a title and the ring below it
/// are two. With one spacing the eye gets no grouping, and the reported symptom
/// was exactly that — "a large uninterrupted gap between the illustration and
/// the title, and the whole stack floats mid-screen without a clear centre of
/// gravity".
///
/// The scale here is roughly a 1.5 ratio between adjacent groups
/// (title→message 10, block→ring 38) so that *proximity* does the grouping and
/// nothing needs a box drawn round it — which is the same reason the surface
/// has no card.
struct RichMetrics: Equatable, Sendable {

  // Type
  let titleSize: CGFloat
  let messageSize: CGFloat
  let footnoteSize: CGFloat

  // Vertical rhythm, each the gap *above* the named element.
  let illustrationToText: CGFloat
  let titleToMessage: CGFloat
  let textToCountdown: CGFloat
  let countdownToButtons: CGFloat
  let buttonsToFootnote: CGFloat

  /// Outer padding, and the width the text block wraps at.
  let contentPadding: CGFloat
  let textWidth: CGFloat

  /// How far above true centre the stack sits, as a fraction of the available
  /// height.
  ///
  /// Optical centring, not a mistake. A stack that is geometrically centred
  /// reads as *low*, because its visual mass is concentrated in the upper half
  /// (illustration, title, ring) while the lower half is a thin button row and
  /// a footnote. Shifting up by a few per cent is the standard correction and
  /// it is what gives the composition a centre of gravity instead of leaving it
  /// adrift. Zero for `.ambient`, where the window is already sized to the
  /// content and there is nothing to centre within.
  let opticalRise: CGFloat

  /// The full-screen surface. Sized for something read from across a desk.
  static let interrupt = RichMetrics(
    titleSize: 30,
    messageSize: 16,
    footnoteSize: 12,
    illustrationToText: 26,
    titleToMessage: 10,
    textToCountdown: 38,
    countdownToButtons: 34,
    buttonsToFootnote: 20,
    contentPadding: 32,
    textWidth: 520,
    opticalRise: 0.035)

  /// The corner toast. Everything smaller and tighter, because the window is
  /// 380×210 and a 30-point title in it is shouting.
  static let ambient = RichMetrics(
    titleSize: 19,
    messageSize: 13,
    footnoteSize: 11,
    illustrationToText: 14,
    titleToMessage: 5,
    textToCountdown: 18,
    countdownToButtons: 16,
    buttonsToFootnote: 12,
    contentPadding: 22,
    textWidth: 340,
    opticalRise: 0)

  static func forMode(_ mode: AlertMode) -> RichMetrics {
    switch mode {
    case .interrupt: return .interrupt
    case .ambient: return .ambient
    }
  }

  // MARK: - Web surface

  /// The two-column surface's share of the screen. Deliberately short of the
  /// edges: the dimmed, blurred desktop showing round all four sides is what
  /// makes this read as *something placed over your work* rather than as an
  /// application that just went full-screen — and the margin is the only thing
  /// separating a black video panel from a black bezel.
  static let webSurfaceWidthFraction: CGFloat = 0.88
  static let webSurfaceHeightFraction: CGFloat = 0.84

  /// The gutter between the web column and the text rail.
  static let webColumnGap: CGFloat = 34

  /// Wide enough for a countdown ring and a two-button row without wrapping.
  /// A rail narrower than this is why `WebPanel.maximumWidthFraction` stops
  /// where it does.
  static let webRailMinimumWidth: CGFloat = 260

  static let webPanelCornerRadius: CGFloat = 18
}
