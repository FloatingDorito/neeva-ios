// Copyright Neeva. All rights reserved.

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import Shared

enum CardUX {
    static let DefaultCardSize : CGFloat = 160
    static let ShadowRadius : CGFloat = 2
    static let CornerRadius : CGFloat = 5
    static let ButtonSize : CGFloat = 28
    static let FaviconSize : CGFloat = 18
    static let HeaderSize : CGFloat = ButtonSize + 1
}

enum CardConfig {
    case carousel
    case grid
}

struct BorderTreatment: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content.overlay(RoundedRectangle(cornerRadius: CardUX.CornerRadius)
                                .stroke(Color.ui.adaptive.blue, lineWidth: 3))
        } else {
            content.shadow(radius: CardUX.ShadowRadius)
        }
    }
}

extension EnvironmentValues {
    private struct SelectionCompletionKey: EnvironmentKey {
        static var defaultValue: (() -> ())? = nil
    }

    public var selectionCompletion: () -> () {
        get { self[SelectionCompletionKey] ?? { fatalError(".environment(\\.selectionCompletion) must be specified") } }
        set { self[SelectionCompletionKey] = newValue }
    }
}

struct Card<Details>: View where Details: CardDetails {
    @ObservedObject var details: Details

    @Environment(\.selectionCompletion) private var selectionCompletion

    let config: CardConfig

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 0) {
                    if let favicon = details.favicon {
                        favicon.resizable()
                            .transition(.fade(duration: 0.5)).background(Color.white)
                            .scaledToFit()
                            .frame(width: CardUX.FaviconSize, height: CardUX.FaviconSize)
                            .cornerRadius(CardUX.CornerRadius)
                            .padding(5)
                    }
                    if let title = details.title {
                        Text(title).withFont(.labelMedium)
                            .frame(maxWidth: .infinity,
                                   alignment: details.favicon == nil ? .center : .leading)
                            .padding(.trailing, 5).padding(.vertical, 4).lineLimit(1)
                    }
                    if let buttonImage = details.closeButtonImage {
                        Button(action: {
                            details.onClose()
                        }, label: {
                            Image(uiImage: buttonImage).resizable().renderingMode(.template)
                                .foregroundColor(.secondaryLabel)
                                .padding(4)
                                .frame(width: CardUX.FaviconSize, height: CardUX.FaviconSize)
                                .padding(5)
                        })
                    }
            }
            .frame(height: CardUX.ButtonSize)
            .background(Color.DefaultBackground)

            Color(UIColor.Browser.urlBarDivider).frame(maxWidth: .infinity, maxHeight: 1)

            Button(action: {
                details.onSelect()
                selectionCompletion()
            }) {
                if let thumbnail = details.thumbnail{
                    thumbnail
                } else {
                    Color.label
                }
            }
        }
        .cornerRadius(CardUX.CornerRadius)
        .modifier(BorderTreatment(isSelected: details.isSelected))
        .onDrop(of: ["public.url", "public.text"], delegate: details)
        .aspectRatio(1, contentMode: .fill)
    }
}

