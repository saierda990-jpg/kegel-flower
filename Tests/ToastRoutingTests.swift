import Foundation

@main
struct ToastRoutingTests {
    static func main() {
        assert(ToastRouting.surface(duration: 0, hasAction: false, hasPrimaryButton: false, hasSecondaryButton: false) == .floatingToast)
        assert(ToastRouting.surface(duration: 2, hasAction: false, hasPrimaryButton: true, hasSecondaryButton: false) == .floatingToast)
        assert(ToastRouting.surface(duration: 2, hasAction: false, hasPrimaryButton: false, hasSecondaryButton: true) == .floatingToast)
        assert(ToastRouting.surface(duration: 2, hasAction: true, hasPrimaryButton: false, hasSecondaryButton: false) == .floatingToast)
        assert(ToastRouting.surface(duration: 2, hasAction: false, hasPrimaryButton: false, hasSecondaryButton: false) == .floatingToast)

        print("ToastRoutingTests passed")
    }
}
