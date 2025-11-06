import SwiftUI
import SVGView

/// SwiftUI view for SVG-based notifications
public struct SVGNotificationView: View {
    let notification: SVGNotification
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var progress: Double = 1.0

    public init(notification: SVGNotification, onDismiss: @escaping () -> Void) {
        self.notification = notification
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 20) {
            // SVG Content
            SVGView(contentsOf: notification.svgSource.url)
                .frame(width: notification.svgSize.width, height: notification.svgSize.height)
                .scaleEffect(scale)
                .opacity(opacity)

            // Title
            if let title = notification.title {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }

            // Message
            if let message = notification.message {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
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
