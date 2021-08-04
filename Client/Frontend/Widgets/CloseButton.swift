// Copyright Neeva. All rights reserved.

import SwiftUI

struct CloseButton: View {
    let action: () -> Void
    var body: some View {
        CloseButtonView(action: action)
            .frame(width: 44, height: 44)
    }
}

private struct CloseButtonView: UIViewRepresentable {
    let action: () -> Void
    private static let actionID = UIAction.Identifier("CloseButton.action")
    class View: UIView {
        var button: UIButton!
    }
    func makeUIView(context: Context) -> View {
        let button = UIButton(type: .close)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)

        let view = View()
        view.button = button
        view.addSubview(button)
        button.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        return view
    }
    func updateUIView(_ view: View, context: Context) {
        view.button.removeAction(identifiedBy: Self.actionID, for: .primaryActionTriggered)
        view.button.addAction(
            UIAction(identifier: Self.actionID) { _ in
                action()
            }, for: .primaryActionTriggered)
    }
    static func dismantleUIView(_ view: View, coordinator: ()) {
        view.button.removeAction(identifiedBy: Self.actionID, for: .primaryActionTriggered)
    }
}

struct CloseButton_Previews: PreviewProvider {
    static var previews: some View {
        CloseButton {}
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
