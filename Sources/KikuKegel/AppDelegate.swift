import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: StatusCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = StatusCoordinator()
    }
}
