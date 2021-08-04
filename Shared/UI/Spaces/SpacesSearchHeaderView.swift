// Copyright Neeva. All rights reserved.

import SwiftUI

struct SpacesSearchHeaderView: View {
    @Binding var searchText: String

    let createAction: () -> Void

    public init(searchText: Binding<String>, createAction: @escaping () -> Void) {
        self._searchText = searchText
        self.createAction = createAction
    }

    var body: some View {
        HStack(spacing: 24) {
            CapsuleTextField(
                "Search Spaces", text: $searchText,
                icon: Symbol(decorative: .magnifyingglass, style: .labelLarge))
            Button {
                self.createAction()
            } label: {
                HStack(spacing: 5) {
                    Symbol(decorative: .plus, style: .labelLarge)
                    Text("Create")
                        .withFont(.labelLarge)
                }
            }
            .frame(height: 40)
            .foregroundColor(.ui.adaptive.blue)
            .padding(.trailing, 3)
        }
    }
}

struct SpacesSearchHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        SpacesSearchHeaderView(searchText: .constant(""), createAction: {})
        SpacesSearchHeaderView(searchText: .constant("Hello, world"), createAction: {})
    }
}
