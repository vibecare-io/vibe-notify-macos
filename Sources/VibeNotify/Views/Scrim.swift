import SwiftUI

/// The local backdrop drawn under a text block when nothing global has already
/// made the surface legible.
///
/// **Scrim is not card.** A card is *bounded*: an edge, a corner radius, a fill
/// uniform right up to that edge, usually a drop shadow announcing it as a
/// sheet stacked on the desktop. It declares *this is a separate object in
/// front of your work* — and that is what was rejected. A scrim is *unbounded*:
/// a luminance gradient with no edge to perceive. It declares nothing; it only
/// says *less light gets through here*.
///
/// Each of the following turns this back into the card, which is why none of
/// them appears in this file and none of them may be added:
/// `RoundedRectangle`, `cornerRadius`, any clip shape, `.regularMaterial` or
/// `NSVisualEffectView`, a stroke or hairline, and a shadow on the scrim
/// itself.
struct FeatheredScrim: View {

  /// Black at the centre of the text block, at the same 0.55 derived for the
  /// interrupt dim — because it is doing the identical job at a smaller radius
  /// of application.
  static let peakOpacity: Double = Legibility.safeDim

  /// Where alpha reaches exactly zero, as a fraction of the drawn rect's half
  /// extent.
  ///
  /// **Must be strictly below 0.5.** `EllipticalGradient`'s `endRadiusFraction`
  /// of 0.5 means "the ellipse touches the edge midpoints", i.e. alpha hits
  /// zero *at* the boundary — and a gradient that ends where its geometry ends
  /// has an edge, which is the card again. At 0.42 the falloff completes well
  /// inside the rect on every axis, so what the eye meets at the boundary is
  /// nothing at all.
  static let endRadiusFraction: CGFloat = 0.42

  /// How far past the text bounds the drawn rect extends. Applied as *negative*
  /// padding on a `.background`, so it grows the scrim outward without moving
  /// any neighbour — the falloff needs room to complete before the geometry
  /// ends, and taking that room from the layout would space the content apart
  /// instead.
  static let feather: CGFloat = 48

  var body: some View {
    // Elliptical rather than a circular `RadialGradient`, and this is a
    // deliberate reading of "radial": a text block is typically wide and short,
    // and a circle sized to reach zero inside the *short* axis leaves the ends
    // of a long title unscrimmed, while one sized for the long axis spills past
    // the top and bottom edges with alpha still on it — an edge, i.e. a card.
    // An ellipse is the same gradient with the rect's aspect, which is what
    // makes "reaches zero inside the rect" true on all four sides at once.
    EllipticalGradient(
      stops: [
        .init(color: .black.opacity(Self.peakOpacity), location: 0),
        .init(color: .black.opacity(Self.peakOpacity * 0.62), location: 0.55),
        .init(color: .black.opacity(0), location: 1),
      ],
      center: .center,
      startRadiusFraction: 0,
      endRadiusFraction: Self.endRadiusFraction
    )
    // The scrim is a luminance decision, not a target. Clicks belong to the
    // buttons and to the full-bleed dismissal target underneath.
    .allowsHitTesting(false)
  }
}

/// The Reduce Transparency alternative: a solid, opaque backdrop with a defined
/// edge.
///
/// This *is* a small card, and that is the decision taken rather than an
/// oversight. A feathered scrim is a transparency gradient by construction and
/// cannot be made opaque and stay edgeless; the two honest options were a solid
/// backdrop or suppressing ambient alerts entirely for these users, and a
/// legible alert beat no alert. Dropping the scrim and relying on shadows alone
/// was not an option — it fails 4.5:1 over a light desktop.
///
/// A plain `Rectangle`, not a rounded one: nothing here is trying to look like
/// a scrim, so there is no ambiguity to introduce.
struct SolidBackdrop: View {
  var body: some View {
    Rectangle()
      .fill(Color.black)
      .allowsHitTesting(false)
  }
}

extension View {
  /// Places the strategy's backdrop behind this view, sized to it and grown
  /// outward by the feather so the falloff completes inside the drawn rect.
  ///
  /// Applied to the three regions this library draws in light ink: the
  /// title/message block, the countdown (ring and dismiss indicator), and the
  /// footnote. Each gets its own scrim rather than one shared rect, because a
  /// single rect spanning them would also cover the buttons sitting between
  /// them — and a gradient that large stops reading as a scrim and starts
  /// reading as a panel.
  ///
  /// Deliberately *not* applied to the illustration, which carries its own
  /// treatment (`IllustrationHalo` for dark artwork, a drop shadow for light —
  /// and neither is a scrim, because a scrim opposes the *backdrop* while those
  /// oppose the artwork's own ink), nor to the buttons, which carry their own
  /// opaque fills. Scrimming those would be drawing a backdrop for something
  /// that already has one.
  @ViewBuilder
  func scrimmed(_ strategy: ScrimStrategy, feather: CGFloat = FeatheredScrim.feather) -> some View {
    switch strategy {
    case .none:
      self
    case .feathered:
      background { FeatheredScrim().padding(-feather) }
    case .solid:
      // A smaller inset than the feather: an opaque rect has no falloff to
      // complete, so the padding here is ordinary breathing room, not headroom
      // for a gradient.
      background { SolidBackdrop().padding(-feather / 2) }
    }
  }
}
