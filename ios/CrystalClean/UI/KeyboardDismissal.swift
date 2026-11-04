import SwiftUI
import UIKit

enum KeyboardFocus {
    static func clear() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Slide the keyboard down with the scroll, offer Done, and tap empty space to dismiss.
    /// Taps on buttons and text fields are left alone so controls, including a pinned Send button, still fire.
    func dismissesKeyboardInteractively() -> some View {
        scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        KeyboardFocus.clear()
                    }
                }
            }
            .background(KeyboardDismissBackground())
    }
}

private struct KeyboardDismissBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let host = uiView.superview, context.coordinator.host !== host else { return }
            let recognizer = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.dismiss)
            )
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = context.coordinator
            host.addGestureRecognizer(recognizer)
            context.coordinator.host = host
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var host: UIView?

        @objc func dismiss() {
            KeyboardFocus.clear()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UIControl || current is UITextView {
                    return false
                }
                view = current.superview
            }
            return true
        }
    }
}
