// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Combine
import Shared
import SwiftUI

class CardStripModel: ObservableObject {
    @ObservedObject var incognitoModel: IncognitoModel
    @ObservedObject var tabCardModel: TabCardModel
    @ObservedObject var tabChromeModel: TabChromeModel

    @Published var shouldEmbedInScrollView = false

    var rows: [Row] {
        incognitoModel.isIncognito
            ? tabCardModel.incognitoRows : tabCardModel.timeBasedNormalRows[.today] ?? []
    }

    var showCardStrip: Bool {
        FeatureFlag[.cardStrip] && tabChromeModel.inlineToolbar && !tabChromeModel.isEditingLocation
            && rows.map { $0.cells.count }.reduce(0, +) > 1
    }

    init(incognitoModel: IncognitoModel, tabCardModel: TabCardModel, tabChromeModel: TabChromeModel)
    {
        self.incognitoModel = incognitoModel
        self.tabCardModel = tabCardModel
        self.tabChromeModel = tabChromeModel
    }
}
