import AppKit
import CoreGraphics
import SwiftUI

/// The soft light bloom drawn *behind* dark artwork, and the mirror image of
/// `FeatheredScrim`.
///
/// **Why the illustration needed its own treatment at all.** The design rule is
/// that a treatment must *oppose* what it sits on: light text takes a dark
/// shadow, and everything in `Legibility.TextStyle` follows that. The
/// illustration was the one element the rule was never applied to — it got a
/// flat `black.opacity(0.5)` drop shadow whatever it contained. For the
/// black-filled `eye.svg` this library actually ships that is a dark shadow
/// under a black silhouette on a 0.55-dimmed desktop: it does nothing, and over
/// the dark half of a split desktop the artwork is very nearly invisible.
/// Measured on the demo harness's `Split Black / White` backdrop before this
/// existed — the left half of the eye simply was not there.
///
/// **Scrim, not card — the same constraint, inverted.** A bloom with a
/// perceptible boundary is a glowing disc stuck behind the artwork, which is
/// the card look arrived at from the other direction. So the alpha ramp reaches
/// exactly zero *inside* the drawn rect (`endRadiusFraction` strictly below
/// 0.5, as in `FeatheredScrim`), and the stop profile is deliberately
/// non-linear — a straight ramp from peak to zero has a visible shoulder where
/// it leaves the peak. What the eye meets at the geometry's edge is nothing at
/// all.
///
/// **Lift, not spotlight.** `peakOpacity` is 0.18, not the scrim's 0.55. Over
/// the interrupt backdrop that is roughly a fifth of the way back to white at
/// the very centre and far less everywhere else — enough that a black
/// silhouette has something to be a silhouette *against*, not enough to read as
/// a white blob or to undo the dim the scrim was derived to provide.
struct IllustrationHalo: View {

  /// Alpha at the dead centre of the bloom.
  ///
  /// Derived by eye against the four demo backdrops rather than from a contrast
  /// ratio, because unlike text there is no glyph/backdrop pair to compute one
  /// for — the artwork is arbitrary. The bound that matters is the *upper* one:
  /// at 0.28 the bloom is legible as a disc on a mid-grey field, at 0.18 it is
  /// not.
  static let peakOpacity: Double = 0.18

  /// Where alpha reaches zero, as a fraction of the drawn rect's extent.
  /// **Strictly below 0.5** for the reason spelled out on
  /// `FeatheredScrim.endRadiusFraction`: at 0.5 the gradient ends exactly where
  /// its geometry does, which is an edge.
  static let endRadiusFraction: CGFloat = 0.46

  /// How far past the artwork's frame the bloom is drawn, applied as negative
  /// padding so it grows outward without moving a single neighbour.
  ///
  /// Larger than the scrim's 48 because the artwork's frame is tighter around
  /// its ink than a text block's is, and because the bloom has to be visibly
  /// *behind* the artwork rather than a rim around it.
  static let feather: CGFloat = 84

  var body: some View {
    EllipticalGradient(
      // Five stops, not two. A two-stop ramp is linear in alpha and the eye
      // finds the point where it leaves the peak; this profile is roughly
      // exponential, so the bloom has no shoulder and no rim.
      stops: [
        .init(color: .white.opacity(Self.peakOpacity), location: 0),
        .init(color: .white.opacity(Self.peakOpacity * 0.74), location: 0.30),
        .init(color: .white.opacity(Self.peakOpacity * 0.36), location: 0.58),
        .init(color: .white.opacity(Self.peakOpacity * 0.11), location: 0.80),
        .init(color: .white.opacity(0), location: 1),
      ],
      center: .center,
      startRadiusFraction: 0,
      endRadiusFraction: Self.endRadiusFraction
    )
    // Elliptical for the same reason the scrim is: illustrations are rarely
    // square, and a circle sized to reach zero inside the short axis leaves the
    // ends of a wide illustration unlit.
    .allowsHitTesting(false)
  }

  /// The tight glow that hugs the artwork's own silhouette.
  ///
  /// The bloom alone is not enough. It is centred on the *frame*, so the
  /// outermost extremities of a wide illustration — the corners of the eye —
  /// sit where the ramp has already fallen away. A `.shadow` follows the drawn
  /// geometry instead of the frame, so it puts light exactly where the ink is,
  /// which is where separation is actually needed.
  ///
  /// Centred rather than displaced, and that is the deliberate opposite of
  /// `Legibility.TextStyle.shadowOffsetY`. A displaced shadow reads as
  /// separation *from a surface*; a centred one reads as glow — and here glow
  /// is the intent, because the thing being opposed is the artwork's own ink,
  /// not a backdrop below it.
  static let glowColor: Color = .white.opacity(0.42)
  static let glowRadius: CGFloat = 14
}

/// Measures how light or dark a piece of artwork actually is, by rendering it.
///
/// **Why measurement rather than a caller-declared flag.** The illustration
/// arrives from somewhere that generally does not know what is in it: the
/// consuming client's plugin path is handed an already-fetched `NSImage` and
/// forwards it, and the schedule path forwards whatever SVG a user pointed at.
/// Requiring the tone to be declared puts the decision at the one call site
/// least able to answer it, and a wrong answer is silent — the artwork just
/// quietly stops being visible on some desktops, which is the exact failure
/// mode this whole library exists to end. Measuring asks the artwork.
///
/// It is also the only approach that covers all three `Illustration` cases with
/// one code path. The alternatives do not: an SVG's ink colour is not readable
/// without parsing (`eye.svg` has four `fill` attributes, three of which belong
/// to degenerate zero-length paths and none of which is the answer on its own),
/// and an SF Symbol's colour is a `Color`, which cannot be resolved to
/// components without a rendering context anyway. Rendering the view the
/// renderer is *about to draw* answers for all three at once, and cannot drift
/// from what ends up on screen.
@MainActor
enum ArtworkLuminance {

  /// Longest edge of the raster used for the measurement. Small on purpose:
  /// this is a mean, not a thumbnail, and an SVG re-parse is the expensive part
  /// either way.
  static let sampleExtent: CGFloat = 64

  /// Alpha below which a pixel counts as background rather than artwork.
  /// Antialiased edges and shadow tails sit under this; a measurement that
  /// included them would drag every illustration toward the backdrop's own
  /// luminance and answer a question about the render, not about the artwork.
  static let inkAlphaFloor: Double = 0.2

  /// Fraction of the sampled area that must be inked before the answer is
  /// trusted. Below it, `nil` — see `Legibility.illustrationTreatment` for what
  /// `nil` resolves to and why.
  static let minimumInkFraction: Double = 0.004

  /// Alpha-weighted mean luminance of `view`'s inked pixels, `0...1`, or `nil`
  /// if it drew essentially nothing.
  ///
  /// Alpha-weighted rather than a plain mean over the mask: a 50%-alpha grey
  /// pixel contributes half as much evidence as a solid one, which is what
  /// keeps a large soft-edged glyph from being scored by its own feathering.
  static func measure<V: View>(_ view: V, naturalSize: CGSize) -> Double? {
    guard naturalSize.width > 0, naturalSize.height > 0 else { return nil }

    let renderer = ImageRenderer(
      content: view.frame(width: naturalSize.width, height: naturalSize.height))
    // Render *down*, never up: the point is a cheap mean.
    renderer.scale = min(1, sampleExtent / max(naturalSize.width, naturalSize.height))
    guard let image = renderer.cgImage else { return nil }
    return meanInkLuminance(of: image)
  }

  /// Walks a `CGImage` once in a known 8-bit sRGB layout.
  ///
  /// Redrawn into a context of our own rather than read through
  /// `CGImage.dataProvider`: `ImageRenderer` does not promise a bitmap layout,
  /// and reading raw bytes out of whatever it happened to produce is how a
  /// measurement silently starts reporting the wrong channel.
  private static func meanInkLuminance(of image: CGImage) -> Double? {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return nil }

    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let ok = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard let base = buffer.baseAddress,
        let context = CGContext(
          data: base,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width * 4,
          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard ok else { return nil }

    var weightedLuminance = 0.0
    var weight = 0.0
    var inked = 0.0

    for index in stride(from: 0, to: pixels.count, by: 4) {
      let alpha = Double(pixels[index + 3]) / 255
      guard alpha > inkAlphaFloor else { continue }
      // Premultiplied, so undo it before reading a colour. Skipping this scores
      // every translucent pixel as darker than it is, which biases *every*
      // illustration toward `.halo`.
      let red = Double(pixels[index]) / 255 / alpha
      let green = Double(pixels[index + 1]) / 255 / alpha
      let blue = Double(pixels[index + 2]) / 255 / alpha
      let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
      weightedLuminance += min(1, luminance) * alpha
      weight += alpha
      inked += 1
    }

    let total = Double(width * height)
    guard weight > 0, inked / total >= minimumInkFraction else { return nil }
    return weightedLuminance / weight
  }
}
