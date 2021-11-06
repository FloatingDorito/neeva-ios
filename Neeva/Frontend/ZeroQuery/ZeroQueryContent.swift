// Copyright Neeva. All rights reserved.

import Combine
import Defaults
import SDWebImage
import Shared
import SnapKit
import Storage
import SwiftUI
import UIKit
import XCGLogger

extension EnvironmentValues {
    private struct HideTopSiteKey: EnvironmentKey {
        static var defaultValue: ((Site) -> Void)? = nil
    }

    public var zeroQueryHideTopSite: (Site) -> Void {
        get {
            self[HideTopSiteKey.self] ?? { _ in
                fatalError(".environment(\\.zeroQueryHideTopSite) must be specified")
            }
        }
        set { self[HideTopSiteKey.self] = newValue }
    }
}

struct ZeroQueryContent: View {
    @ObservedObject var model: ZeroQueryModel
    @EnvironmentObject var suggestedSitesViewModel: SuggestedSitesViewModel
    @EnvironmentObject var suggestedSearchesModel: SuggestedSearchesModel

    var body: some View {
        ZeroQueryView()
            .background(Color(UIColor.HomePanel.topSitesBackground))
            .environmentObject(model)
            .environment(\.setSearchInput) { query in
                model.delegate?.zeroQueryPanel(didEnterQuery: query)
            }
            .environment(\.onOpenURL) { url in
                model.delegate?.zeroQueryPanel(didSelectURL: url, visitType: .bookmark)
            }
            .environment(\.shareURL, model.shareURLHandler)
            .environment(\.zeroQueryHideTopSite, model.hideURLFromTopSites)
            .environment(\.openInNewTab) { url, isPrivate in
                model.delegate?.zeroQueryPanelDidRequestToOpenInNewTab(
                    url, isPrivate: isPrivate)
            }
            .environment(\.saveToSpace) { url, title, description in
                model.delegate?.zeroQueryPanelDidRequestToSaveToSpace(
                    url,
                    title: title,
                    description: description)
            }
            .onAppear {
                self.model.updateState()
                self.suggestedSearchesModel.reload(from: self.model.profile)
            }
    }
}
