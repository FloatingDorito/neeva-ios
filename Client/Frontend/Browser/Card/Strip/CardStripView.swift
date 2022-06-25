// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Combine
import Shared
import Storage
import SwiftUI

struct CardStripUX {
    static let Height: CGFloat = 40
}

struct CardStripView: View {
    @EnvironmentObject private var incognitoModel: IncognitoModel
    @EnvironmentObject private var model: CardStripModel
    @EnvironmentObject private var scrollingControlModel: ScrollingControlModel
    @EnvironmentObject private var tabCardModel: TabCardModel

    var pinnedDetails: [TabCardDetails] {
        return tabCardModel.allDetails.filter { $0.isPinned }
    }

    @ViewBuilder
    var content: some View {
        HStack(spacing: 16) {
            if pinnedDetails.count > 0 {
                HStack(spacing: 0) {
                    ForEach(pinnedDetails.indices, id: \.self) { index in
                        CardStripCard(details: pinnedDetails[index])
                            .padding(.trailing, pinnedDetails.count - 1 == index ? -16 : 0)
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(model.unpinnedDetails.indices, id: \.self) { index in
                    CardStripCard(details: model.unpinnedDetails[index])
                }
            }
        }
    }

    var body: some View {
        content
            .opacity(scrollingControlModel.controlOpacity)
            .frame(height: CardStripUX.Height)
            .frame(maxWidth: .infinity)
            .background(Color.DefaultBackground)
    }
}
