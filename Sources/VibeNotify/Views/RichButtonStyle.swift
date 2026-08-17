import SwiftUI

/// The button style for the rich renderer.
///
/// **Why not `PrimaryButtonStyle` / `SecondaryButtonStyle` /
/// `DestructiveButtonStyle`** (`StandardNotificationView.swift:166-194`): those
/// are card chrome. They are a flat `Color.accentColor` or
/// `Color.secondary.opacity(0.2)` fill with a `.primary` label, which works on
/// an opaque `windowBackgroundColor` card and vanishes against a blurred light
/// desktop — a `.primary` label is *black* in light mode, and
/// `secondary.opacity(0.2)` over a bright backdrop is very nearly nothing. The
/// consuming client hit exactly this and wrote its own material-backed style
/// with a comment saying so; shipping this one is what lets that private copy
/// be deleted.
///
/// "Chrome-less" here means the alert has no card, not that the buttons have no
/// shape. The buttons sit *outside* the scrim — the scrim is behind the text
/// block only — so each one has to carry its own contrast, in both directions,
/// over a backdrop the library does not own. That means an opaque fill and a
/// label chosen against that fill, never against the desktop.
struct RichButtonStyle: SwiftUI.ButtonStyle {

  let role: StandardNotification.Button.ButtonStyle

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .semibold))
      .tracking(0.2)
      .foregroundColor(labelColor)
      .padding(.horizontal, 24)
      .padding(.vertical, 11)
      .background(
        // Two fills for the non-primary roles, and this is the change that
        // makes the row read as one family. An opaque `black.opacity(0.42)`
        // capsule beside an opaque white one is not "primary and secondary", it
        // is two unrelated buttons — the reported reading. The dark layer is
        // still there because a button sits *outside* the scrim and has to
        // carry contrast over a desktop this library does not own; the light
        // layer on top is what puts it on the same axis as the primary, so the
        // pair now differs only in how much white each one has.
        ZStack {
          Capsule().fill(underFill)
          Capsule().fill(fill)
        }
      )
      .overlay(
        // A hairline is forbidden on the *scrim*, where it would give an
        // edgeless gradient an edge. A button is supposed to have an edge —
        // this is what keeps the translucent secondary fill from dissolving
        // into a dark desktop.
        Capsule().strokeBorder(border, lineWidth: 1)
      )
      // Opposing the label, exactly as the text shadows do.
      .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
      .opacity(configuration.isPressed ? 0.75 : 1.0)
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      // Press feedback is the one animation here, and it is a response to the
      // user's own finger rather than an entrance, so Reduce Motion leaves it
      // alone.
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
      .contentShape(Capsule())
  }

  /// Opaque white for the primary action: the strongest thing available
  /// against a dark scrim, and unlike an accent fill it cannot be tinted into
  /// invisibility by a user's accent-colour preference.
  private var fill: Color {
    switch role {
    case .primary: return .white
    // White at a low alpha, not black at a high one: the whole row is then
    // "white at 1.0" beside "white at 0.16", which reads as one control in two
    // strengths. `underFill` supplies the contrast floor underneath.
    case .secondary: return .white.opacity(0.16)
    case .destructive: return Color(red: 0.85, green: 0.24, blue: 0.24)
    }
  }

  /// The opaque-ish layer beneath `fill`, present only where `fill` is
  /// translucent. Without it the secondary button dissolves into a blurred
  /// light desktop, which is the failure `black.opacity(0.42)` was there to
  /// prevent and which this must not reintroduce.
  private var underFill: Color {
    switch role {
    case .primary, .destructive: return .clear
    case .secondary: return .black.opacity(0.30)
    }
  }

  private var labelColor: Color {
    switch role {
    case .primary: return .black
    case .secondary, .destructive: return .white
    }
  }

  private var border: Color {
    switch role {
    case .primary: return .clear
    case .secondary: return .white.opacity(0.30)
    case .destructive: return .white.opacity(0.18)
    }
  }
}
