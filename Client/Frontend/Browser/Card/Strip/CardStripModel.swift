// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Combine
import Shared
import SwiftUI

class CardStripModel: ObservableObject {
    @ObservedObject var tabCardModel: TabCardModel
    @ObservedObject var tabChromeModel: TabChromeModel

    var showCardStrip: Bool {
        FeatureFlag[.cardStrip] && tabChromeModel.inlineToolbar && !tabChromeModel.isEditingLocation
            && tabCardModel.todaysDetails.filter { !$0.isPinned }.count > 1
    }

    init(tabCardModel: TabCardModel, tabChromeModel: TabChromeModel) {
        self.tabCardModel = tabCardModel
        self.tabChromeModel = tabChromeModel
    }
}
