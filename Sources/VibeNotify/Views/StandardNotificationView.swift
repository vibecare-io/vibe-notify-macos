import SwiftUI

/// SwiftUI view for standard notifications
public struct StandardNotificationView: View {
    let notification: StandardNotification
    let onDismiss: () -> Void

    @State private var progress: Double = 1.0

    public init(notification: StandardNotification, onDismiss: @escaping () -> Void) {
        self.notification = notification
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Icon
            if let icon = notification.icon {
                iconView(for: icon)
                    .font(.system(size: 48))
                    .foregroundColor(icon.color)
            }

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

            // Buttons
            if !notification.buttons.isEmpty {
                HStack(spacing: 12) {
                    ForEach(notification.buttons) { button in
                        buttonView(for: button)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(notification.style.padding)
        .background(notification.style.backgroundColor)
        .cornerRadius(notification.style.cornerRadius)
        .if(notification.style.shadow != nil) { view in
            view.shadow(
                color: notification.style.shadow!.color,
                radius: notification.style.shadow!.radius,
                x: notification.style.shadow!.x,
                y: notification.style.shadow!.y
            )
        }
        .onAppear {
            if let autoDismiss = notification.autoDismiss {
                startAutoDismissTimer(delay: autoDismiss.delay, showProgress: autoDismiss.showProgress)
            }
        }
    }

    @ViewBuilder
    private func iconView(for icon: StandardNotification.IconType) -> some View {
        switch icon {
        case .system, .success, .error, .warning, .info:
            if let systemName = icon.systemName {
                Image(systemName: systemName)
            }
        case .image(let nsImage):
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
        case .svg, .url:
            // SVG and URL icons handled separately
            EmptyView()
        }
    }

    @ViewBuilder
    private func buttonView(for button: StandardNotification.Button) -> some View {
        switch button.style {
        case .primary:
            SwiftUI.Button(action: {
                button.action()
                onDismiss()
            }) {
                Text(button.title)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(PrimaryButtonStyle())
        case .secondary:
            SwiftUI.Button(action: {
                button.action()
                onDismiss()
            }) {
                Text(button.title)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(SecondaryButtonStyle())
        case .destructive:
            SwiftUI.Button(action: {
                button.action()
                onDismiss()
            }) {
                Text(button.title)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(DestructiveButtonStyle())
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

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.secondary.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - View Extension for Conditional Modifiers

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
