// Copyright Neeva. All rights reserved.

import Introspect
import SwiftUI

fileprivate struct SaveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Capsule()
            .fill(configuration.isPressed ? Color(hex: 0x3254CE) : Color.neeva.ui.blue)
            .frame(height: 44)
            .overlay(
                configuration.label
                    .foregroundColor(.white)
            )
    }
}

struct CreateSpaceView: View {
    @State private var spaceName = ""
    let onDismiss: (String) -> ()

    public init(onDismiss: @escaping (String) -> ()) {
        self.onDismiss = onDismiss
    }

    var body: some View{
        VStack(spacing: 20) {
            CapsuleTextField("Space name", text: $spaceName)

            Button(action: {
                self.onDismiss(self.spaceName)
            }) {
                Text("Save").fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(SaveButtonStyle())
            .padding(.bottom, 11)
        }.padding(16)
        // Focus the text field automatically when loading this view. Unfortunately,
        // SwiftUI provides no way to do this, so we have to resort to using Introspect.
        // See https://github.com/siteline/SwiftUI-Introspect/issues/99 for why this is
        // here instead of right below the TextField() instantiation above.
        .introspectTextField { textField in
            textField.becomeFirstResponder()
        }
    }
}
struct CreateSpaceView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CreateSpaceView(onDismiss: { _ in })
            CreateSpaceView(onDismiss: { _ in })
                .preferredColorScheme(.dark)
        }.previewLayout(.sizeThatFits)
    }
}


