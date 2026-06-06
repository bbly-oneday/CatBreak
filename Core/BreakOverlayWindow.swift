import AppKit
import SwiftUI

class BreakOverlayWindow {
    private var window: NSWindow?
    private let breakDuration: Int
    private var countdownTimer: Timer?
    private var remainingSeconds: Int

    init(breakDuration: Int) {
        self.breakDuration = breakDuration
        self.remainingSeconds = breakDuration
    }

    func show() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Set to highest window level - screen saver level
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false

        // Content view with cat overlay
        let catView = CatOverlayView(remainingSeconds: remainingSeconds)
        window.contentView = NSHostingView(rootView: catView)

        self.window = window
        window.makeKeyAndOrderFront(nil)

        // Start countdown
        startCountdown()
    }

    func hide() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        window?.orderOut(nil)
        window = nil
    }

    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.remainingSeconds -= 1

            if self.remainingSeconds <= 0 {
                timer.invalidate()
                self.hide()
            } else {
                // Update the content view
                if let contentView = self.window?.contentView {
                    let updatedView = CatOverlayView(remainingSeconds: self.remainingSeconds)
                    contentView = NSHostingView(rootView: updatedView)
                }
            }
        }
    }
}
