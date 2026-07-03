import Foundation

struct PopoverActionNotice {
    let title: String
    let subtitle: String
    let systemImageName: String?
    let layout: ToastLayout
    let primaryButtonTitle: String?
    let primaryAction: (() -> Void)?
    let secondaryButtonTitle: String?
    let secondaryAction: (() -> Void)?
}

final class PopoverNoticeStore: ObservableObject {
    @Published var notice: PopoverActionNotice?
}
