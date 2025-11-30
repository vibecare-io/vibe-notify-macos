import SVGView
import SwiftUI

/// SwiftUI view for SVG-based notifications
public struct SVGNotificationView: View {
  let notification: SVGNotification
  let onDismiss: () -> Void
  let screenBlurActive: Bool

  @Environment(\.colorScheme) private var colorScheme

  @State private var scale: CGFloat = 0.8
  @State private var opacity: Double = 0.0
  @State private var progress: Double = 1.0

  /// Determines if light text should be used based on system theme
  private var useLightText: Bool {
    // Follow system theme: dark mode = light text, light mode = dark text
    colorScheme == .dark
  }

  public init(
    notification: SVGNotification,
    screenBlurActive: Bool = false,
    onDismiss: @escaping () -> Void
  ) {
    self.notification = notification
    self.screenBlurActive = screenBlurActive
    self.onDismiss = onDismiss
  }

  public var body: some View {
    VStack(spacing: 20) {
      // SVG Content with adaptive glow/shadow
      SVGView(contentsOf: notification.svgSource.url)
        .frame(width: notification.svgSize.width, height: notification.svgSize.height)
        .shadow(color: useLightText ? .white.opacity(0.5) : .black.opacity(0.5), radius: 15)
        .scaleEffect(scale)
        .opacity(opacity)

      // Title
      if let title = notification.title {
        Text(title)
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundColor(useLightText ? .white : .primary)
          .shadow(color: useLightText ? .white.opacity(0.3) : .clear, radius: 4, x: 0, y: 0)
          .multilineTextAlignment(.center)
      }

      // Message
      if let message = notification.message {
        Text(message)
          .font(.body)
          .foregroundColor(useLightText ? .white.opacity(0.9) : .secondary)
          .shadow(color: useLightText ? .white.opacity(0.2) : .clear, radius: 3, x: 0, y: 0)
          .multilineTextAlignment(.center)
      }

      // Auto-dismiss progress bar
      if let autoDismiss = notification.autoDismiss, autoDismiss.showProgress {
        ProgressView(value: progress)
          .progressViewStyle(.linear)
          .frame(maxWidth: 300)
      }

      // Dismiss button for interactive SVGs
      if notification.interactive {
        SwiftUI.Button("Dismiss") {
          onDismiss()
        }
        .buttonStyle(SecondaryButtonStyle())
      }
    }
    .padding(24)
    .onAppear {
      withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
        scale = 1.0
        opacity = 1.0
      }

      // Start auto-dismiss timer if configured
      if let autoDismiss = notification.autoDismiss {
        startAutoDismissTimer(delay: autoDismiss.delay, showProgress: autoDismiss.showProgress)
      }
    }
    .onTapGesture {
      if !notification.interactive {
        onDismiss()
      }
    }
  }

  private func startAutoDismissTimer(delay: TimeInterval, showProgress: Bool) {
    if showProgress {
      // Animate progress bar
      withAnimation(.linear(duration: delay)) {
        progress = 0.0
      }
    }

    // Dismiss after delay
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      onDismiss()
    }
  }
}
