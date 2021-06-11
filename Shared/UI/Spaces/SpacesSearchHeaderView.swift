// Copyright Neeva. All rights reserved.

import SwiftUI

struct SpacesSearchHeaderView: View {
    @Binding var searchText: String

    let createAction: () -> ()

    public init(searchText: Binding<String>, createAction: @escaping () -> ()) {
        self._searchText = searchText
        self.createAction = createAction
    }

    var body: some View {
        HStack(spacing: 24) {
            CapsuleTextField("Search Spaces", text: $searchText, icon: Symbol(.magnifyingglass))
            Button {
                self.createAction()
            } label: {
                HStack(spacing: 5) {
                    Symbol(.plus, size: 16, weight: .semibold)
                    Text("Create")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(height: 40)
            .foregroundColor(.neeva.ui.blue)
            .padding(.trailing, 3)
        }
    }
}

struct SpacesSearchHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        SpacesSearchHeaderView(searchText: .constant(""), createAction: { } )
        SpacesSearchHeaderView(searchText: .constant("Hello, world"), createAction: { } )
    }
}

