import SwiftUI
import UIKit

extension View {
    /// Lets the last row scroll above the floating tab bar.
    /// The margin is the part of this scroll view that sits under the tab bar
    /// and is not already in the scroll view's safe-area inset.
    func clearsFloatingTabBar() -> some View {
        modifier(FloatingTabBarClearance())
    }
}

private struct FloatingTabBarClearance: ViewModifier {
    @State private var extra: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.bottom, extra, for: .scrollContent)
            .background {
                TabBarOverlapProbe(currentExtra: extra) { next in
                    if abs(extra - next) > 0.5 {
                        extra = next
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

private struct TabBarOverlapProbe: UIViewControllerRepresentable {
    var currentExtra: CGFloat
    var onChange: (CGFloat) -> Void

    func makeUIViewController(context: Context) -> Probe {
        Probe()
    }

    func updateUIViewController(_ probe: Probe, context: Context) {
        probe.currentExtra = currentExtra
        probe.onChange = onChange
        probe.scheduleReport()
    }

    final class Probe: UIViewController {
        var currentExtra: CGFloat = 0
        var onChange: (CGFloat) -> Void = { _ in }
        private var scheduled = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            scheduleReport()
        }

        override func viewSafeAreaInsetsDidChange() {
            super.viewSafeAreaInsetsDidChange()
            scheduleReport()
        }

        func scheduleReport() {
            guard !scheduled else { return }
            scheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scheduled = false
                self.report()
            }
        }

        private func report() {
            guard let window = view.window, let tabFrame = tabBarFrame(in: window) else { return }
            let container = scrollView() ?? view
            let containerFrame = container.convert(container.bounds, to: window)
            let overlap = containerFrame.maxY - tabFrame.minY
            guard overlap > 1 else {
                publish(0)
                return
            }
            let applied = scrollView()?.adjustedContentInset.bottom ?? 0
            let baseApplied = max(0, applied - currentExtra)
            let missing = max(0, overlap - baseApplied)
            publish(missing > 1 ? missing + 12 : 12)
        }

        private func publish(_ value: CGFloat) {
            if abs(value - currentExtra) > 0.5 {
                onChange(value)
            }
        }

        private func tabBarFrame(in window: UIWindow) -> CGRect? {
            let bar = tabBarController?.tabBar ?? Self.findTabBar(in: window)
            guard let bar, !bar.isHidden, bar.bounds.height > 1 else { return nil }
            return bar.convert(bar.bounds, to: window)
        }

        private func scrollView() -> UIScrollView? {
            var node: UIView? = view
            while let current = node {
                if let scroll = current as? UIScrollView { return scroll }
                if let parent = current.superview {
                    for sibling in parent.subviews where sibling !== current {
                        if let scroll = sibling as? UIScrollView { return scroll }
                        if let scroll = Self.firstScrollView(in: sibling, depth: 4) { return scroll }
                    }
                }
                node = current.superview
            }
            return nil
        }

        private static func findTabBar(in view: UIView) -> UITabBar? {
            if let bar = view as? UITabBar { return bar }
            for child in view.subviews {
                if let found = findTabBar(in: child) { return found }
            }
            return nil
        }

        private static func firstScrollView(in view: UIView, depth: Int) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            guard depth > 0 else { return nil }
            for child in view.subviews {
                if let found = firstScrollView(in: child, depth: depth - 1) { return found }
            }
            return nil
        }
    }
}
