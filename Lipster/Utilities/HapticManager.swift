import UIKit

/// Centralized haptic feedback for transport controls and UI interactions.
enum Haptics {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let selectionFeedback = UISelectionFeedbackGenerator()
    private static let notificationFeedback = UINotificationFeedbackGenerator()

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        switch style {
        case .light:
            lightImpact.impactOccurred()
        case .medium:
            mediumImpact.impactOccurred()
        default:
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    static func selection() {
        selectionFeedback.selectionChanged()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationFeedback.notificationOccurred(type)
    }
}
