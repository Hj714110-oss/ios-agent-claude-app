import SwiftUI
import UIKit

struct EditorBridgeView: UIViewRepresentable {
    @Binding var text: String

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: EditorBridgeView

        init(parent: EditorBridgeView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
}
