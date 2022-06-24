// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Shared
import SwiftUI

struct CardStripCard<Details>: View where Details: TabCardDetails {
    @ObservedObject var details: Details

    @EnvironmentObject var browserModel: BrowserModel
    @EnvironmentObject var incognitoModel: IncognitoModel
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.selectionCompletion) private var selectionCompletion: () -> Void

    var animate = false
    @State private var width: CGFloat = 0

    private let minimumContentWidthRequirement: CGFloat = 115
    private let squareSize = CardUX.FaviconSize + 1
    private var preferredWidth: CGFloat {
        return
            details.title.size(withAttributes: [
                .font: FontStyle.labelMedium.uiFont(for: sizeCategory)
            ]).width + CardUX.CloseButtonSize + CardUX.FaviconSize + 45  // miscellaneous padding
    }

    @ViewBuilder
    var buttonContent: some View {
        HStack {
            if width <= minimumContentWidthRequirement {
                Spacer()
            }

            HStack {
                if let favicon = details.favicon {
                    favicon
                        .frame(width: CardUX.FaviconSize, height: CardUX.FaviconSize)
                        .cornerRadius(CardUX.FaviconCornerRadius)
                        .padding(5)
                        .padding(.vertical, 6)
                }

                if width > minimumContentWidthRequirement {
                    Text(details.title).withFont(.labelMedium)
                        .lineLimit(1)
                        .padding(.trailing, 5)
                        .padding(.vertical, 4)
                }
            }

            Spacer()

            if let image = details.closeButtonImage, width > minimumContentWidthRequirement - 15 {
                Button(action: details.onClose) {
                    Image(uiImage: image)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.secondaryLabel)
                        .padding(8)
                        .frame(width: CardUX.CloseButtonSize, height: CardUX.CloseButtonSize)
                        .background(Color(UIColor.systemGray6))
                        .clipShape(Circle())
                        .accessibilityLabel("Close \(details.title)")
                        .opacity(animate && !browserModel.showGrid ? 0 : 1)
                }
            }
        }
    }

    var card: some View {
        Button {
            selectionCompletion()
            details.onSelect()
        } label: {
            if details.isPinned {
                buttonContent
                    .frame(width: CardUX.FaviconSize + 12)
            } else {
                buttonContent
                    .frame(minWidth: details.isSelected ? preferredWidth : CardUX.FaviconSize + 12)
            }
        }
        .padding(.horizontal)
        .onWidthOfViewChanged { width in
            self.width = width
        }
    }

    var body: some View {
        card
            .background(
                details.isSelected ? Color.DefaultBackground : Color.groupedBackground
            ).contextMenu(menuItems: details.contextMenu)
    }
}
