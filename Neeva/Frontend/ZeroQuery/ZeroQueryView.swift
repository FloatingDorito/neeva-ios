// Copyright Neeva. All rights reserved.

import Defaults
import Shared
import Storage
import SwiftUI

public struct ZeroQueryUX {
    fileprivate static let ToggleButtonSize: CGFloat = 32
    fileprivate static let ToggleIconSize: CGFloat = 14
    static let Padding: CGFloat = 16
}

extension EnvironmentValues {
    private struct ZeroQueryWidthKey: EnvironmentKey {
        static let defaultValue: CGFloat = 0
    }
    /// The width of the zero query view, in points.
    var zeroQueryWidth: CGFloat {
        get { self[ZeroQueryWidthKey.self] }
        set { self[ZeroQueryWidthKey.self] = newValue }
    }
}

private enum TriState: Int, Codable {
    case hidden
    case compact
    case expanded

    var verb: String {
        switch self {
        case .hidden: return "shows"
        case .compact: return "expands"
        case .expanded: return "hides"
        }
    }

    var icon: Nicon {
        switch self {
        case .hidden: return .chevronDown
        case .compact: return .doubleChevronDown
        case .expanded: return .chevronUp
        }
    }

    var next: TriState {
        switch self {
        case .hidden: return .compact
        case .compact: return .expanded
        case .expanded: return .hidden
        }
    }

    mutating func advance() {
        self = self.next
    }
}

extension Defaults.Keys {
    fileprivate static let expandSuggestedSites = Defaults.Key<TriState>(
        "profile.home.suggestedSites.expanded", default: .compact)
    fileprivate static let expandSearches = Defaults.Key<Bool>(
        "profile.home.searches.expanded", default: true)
    fileprivate static let expandSpaces = Defaults.Key<Bool>(
        "profile.home.spaces.expanded", default: true)
}

struct ZeroQueryHeader: View {
    let title: String
    let action: () -> Void
    let label: String
    let icon: Nicon

    var body: some View {
        HStack {
            Text(title)
                .withFont(.headingMedium)
                .foregroundColor(.secondaryLabel)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer()
            Button(action: action) {
                // decorative because the toggle action is expressed on the header view itself.
                // This button is not an accessibility element.
                Symbol(decorative: icon, size: ZeroQueryUX.ToggleIconSize, weight: .medium)
                    .frame(
                        width: ZeroQueryUX.ToggleButtonSize, height: ZeroQueryUX.ToggleButtonSize,
                        alignment: .center
                    )
                    .background(Color(light: .ui.gray98, dark: .systemFill)).clipShape(Circle())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits([.isHeader, .isButton])
        .accessibilityLabel("\(title), \(label)")
        .accessibilityAction(.default, action)
        .padding([.top, .horizontal], ZeroQueryUX.Padding)
    }
}

struct ZeroQueryPlaceholder: View {
    let label: String

    var body: some View {
        HStack {
            Spacer()
            Text(label)
                .withFont(.bodyMedium)
                .multilineTextAlignment(.center)
            Spacer()
        }.padding(.vertical, 12)
    }
}

struct ZeroQueryView: View {
    @EnvironmentObject var viewModel: ZeroQueryModel

    @Default(.expandSuggestedSites) private var expandSuggestedSites
    @Default(.expandSearches) private var expandSearches
    @Default(.expandSpaces) private var expandSpaces
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func ratingsCard(_ viewWidth: CGFloat) -> some View {
        RatingsCard(
            onClose: {
                viewModel.showRatingsCard = false
                Defaults[.ratingsCardHidden] = true
                UserFlagStore.shared.setFlag(
                    .dismissedRatingPromo,
                    action: {})
            },
            onFeedback: {
                showFeedbackPanel(bvc: viewModel.bvc, shareURL: false)
            },
            viewWidth: viewWidth)
    }

    func isLandScape() -> Bool {
        return horizontalSizeClass == .regular
            || (horizontalSizeClass == .compact && verticalSizeClass == .compact)
    }

    var body: some View {
        GeometryReader { geom in
            ScrollView {
                VStack(spacing: 0) {
                    if NeevaFeatureFlags[.clientHideSearchBox],
                        let searchQuery = viewModel.searchQuery, let url = viewModel.tabURL
                    {
                        SearchSuggestionView(
                            Suggestion.editCurrentQuery(searchQuery, url)
                        )
                        .environmentObject(viewModel.bvc.suggestionModel)

                        SuggestionsDivider(height: 8)
                    } else if let openTab = viewModel.openedFrom?.openedTab {
                        SearchSuggestionView(
                            Suggestion.editCurrentURL(
                                TabCardDetails(
                                    tab: openTab,
                                    manager: viewModel.bvc.tabManager)
                            )
                        )
                        .environmentObject(viewModel.bvc.suggestionModel)

                        SuggestionsDivider(height: 8)
                    }

                    if viewModel.isPrivate {
                        IncognitoDescriptionView().clipShape(RoundedRectangle(cornerRadius: 12.0))
                            .padding(ZeroQueryUX.Padding)
                    } else {
                        if let promoCardType = viewModel.promoCard {
                            PromoCard(type: promoCardType, viewWidth: geom.size.width)
                        }

                        if isLandScape() && viewModel.showRatingsCard {
                            ratingsCard(geom.size.width)
                        }

                        if !NeevaUserInfo.shared.isUserLoggedIn,
                            !SpaceStore.suggested.allSpaces.isEmpty
                        {
                            ZeroQueryHeader(
                                title: "Spaces from Neeva community",
                                action: { expandSpaces.toggle() },
                                label: "\(expandSpaces ? "hides" : "shows") this section",
                                icon: expandSpaces ? .chevronUp : .chevronDown
                            )
                            if expandSpaces {
                                SuggestedSpacesView()
                            }
                        }

                        ZeroQueryHeader(
                            title: "Suggested sites",
                            action: { expandSuggestedSites.advance() },
                            label: "\(expandSuggestedSites.verb) this section",
                            icon: expandSuggestedSites.icon
                        )
                        if expandSuggestedSites != .hidden {
                            SuggestedSitesView(isExpanded: expandSuggestedSites == .expanded)
                        }

                        if !isLandScape() && viewModel.showRatingsCard {
                            ratingsCard(geom.size.width)
                        }

                        ZeroQueryHeader(
                            title: "Searches",
                            action: { expandSearches.toggle() },
                            label: "\(expandSearches ? "hides" : "shows") this section",
                            icon: expandSearches ? .chevronUp : .chevronDown
                        )
                        if expandSearches {
                            SuggestedSearchesView()
                        }

                        if NeevaUserInfo.shared.isUserLoggedIn {
                            ZeroQueryHeader(
                                title: "Spaces",
                                action: { expandSpaces.toggle() },
                                label: "\(expandSpaces ? "hides" : "shows") this section",
                                icon: expandSpaces ? .chevronUp : .chevronDown
                            )
                            if expandSpaces {
                                SuggestedSpacesView()
                            }
                        }
                    }

                    Spacer()
                }
            }.environment(\.zeroQueryWidth, geom.size.width).animation(nil)
        }
    }
}

#if DEBUG
    struct ZeroQueryView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                ZeroQueryView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .environmentObject(
                ZeroQueryModel(
                    bvc: SceneDelegate.getBVC(for: nil),
                    profile: BrowserProfile(localName: "profile"), shareURLHandler: { _, _ in })
            )
            .environmentObject(SuggestedSitesViewModel.preview)
            .environmentObject(
                SuggestedSearchesModel(
                    suggestedQueries: [
                        ("lebron james", .init(url: "https://neeva.com", title: "", guid: "1")),
                        ("neeva", .init(url: "https://neeva.com", title: "", guid: "2")),
                        ("knives out", .init(url: "https://neeva.com", title: "", guid: "3")),
                    ]
                )
            )
        }
    }
#endif
