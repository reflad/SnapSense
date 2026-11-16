import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class ToastWindowController {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(message: String, below anchorFrame: CGRect, screenFrame: CGRect) {
        dismissTask?.cancel()

        let size = NSSize(width: 222, height: 38)
        let panel = panel ?? makePanel()
        self.panel = panel

        let hostingView = NSHostingView(
            rootView: ToastView(message: message)
                .frame(width: size.width, height: size.height)
        )
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView
        panel.setContentSize(size)
        panel.setFrameOrigin(
            origin(
                for: size,
                below: anchorFrame,
                screenFrame: screenFrame
            )
        )

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
    }

    private func fadeOut() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
                self?.panel?.alphaValue = 1
            }
        }
    }

    private func origin(
        for size: NSSize,
        below anchorFrame: CGRect,
        screenFrame: CGRect
    ) -> NSPoint {
        let margin: CGFloat = 8
        var y = anchorFrame.minY - size.height - margin
        if y < screenFrame.minY + margin {
            y = anchorFrame.maxY + margin
        }

        var x = anchorFrame.midX - size.width / 2
        x = min(
            max(x, screenFrame.minX + margin),
            screenFrame.maxX - size.width - margin
        )
        y = min(
            max(y, screenFrame.minY + margin),
            screenFrame.maxY - size.height - margin
        )

        return NSPoint(x: x, y: y)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        return panel
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 5)
        .preferredColorScheme(.dark)
    }
}
