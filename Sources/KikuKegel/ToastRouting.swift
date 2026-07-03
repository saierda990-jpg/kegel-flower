import Foundation

enum ToastSurface {
    case anchoredPopover
    case floatingToast
}

enum ToastRouting {
    static func surface(
        duration: TimeInterval,
        hasAction: Bool,
        hasPrimaryButton: Bool,
        hasSecondaryButton: Bool
    ) -> ToastSurface {
        return .floatingToast
    }
}
