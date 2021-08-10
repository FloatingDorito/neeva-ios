// Copyright Neeva. All rights reserved.

import Shared
import Storage
import SwiftUI

private enum SuggestedSiteUX {
    static let FaviconSize: CGFloat = 28
    static let IconSize: CGFloat = 40
    static let PinIconSize: CGFloat = 12
    static let IconCornerRadius: CGFloat = 4
    static let BlockSize: CGFloat = 64
    static let BlockSpacing: CGFloat = 24
}

struct SuggestedSiteView: View {
    let site: Site!
    let isPinnedSite: Bool!

    @EnvironmentObject private var viewModel: SuggestedSitesViewModel

    @Environment(\.onOpenURL) private var openURL
    @Environment(\.shareURL) private var shareURL
    @Environment(\.openInNewTab) private var openInNewTab
    @Environment(\.zeroQueryHideTopSite) private var zeroQueryHideTopSite
    @Environment(\.saveToSpace) private var saveToSpace

    @State private var isDeleting = false

    var title: String {
        if let provider = site.metadata?.providerName {
            return provider.capitalized
        } else {
            return site.tileURL.shortDisplayString.capitalized
        }
    }

    var hint: String {
        let pinned = isPinnedSite ? "Pinned " : ""
        return pinned + "Suggested Site"
    }

    var body: some View {
        Button(action: { openURL(site.url) }) {
            VStack(spacing: 2) {
                FaviconView(
                    url: site.url, icon: site.icon, size: SuggestedSiteUX.FaviconSize,
                    bordered: false
                )
                .frame(
                    width: SuggestedSiteUX.IconSize, height: SuggestedSiteUX.IconSize,
                    alignment: .center
                )
                .background(Color(light: .ui.gray97, dark: .systemFill))
                .cornerRadius(SuggestedSiteUX.IconCornerRadius)
                HStack {
                    if isPinnedSite {
                        Image("pin_small").renderingMode(.template).foregroundColor(Color.ui.gray60)
                            .frame(
                                width: SuggestedSiteUX.PinIconSize,
                                height: SuggestedSiteUX.PinIconSize, alignment: .center)
                    }
                    Text(title)
                        .withFont(.bodyMedium)
                        .lineLimit(1)
                        .background(
                            RoundedRectangle(cornerRadius: 4).fill(Color.background).padding(-4)
                        )
                        .padding(.top, 4)
                        .foregroundColor(.secondaryLabel)
                }
                .contentShape(Rectangle())
            }
            .frame(width: SuggestedSiteUX.BlockSize, height: SuggestedSiteUX.BlockSize)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityHint(hint)
            .contextMenu {
                ZeroQueryCommonContextMenuActions(siteURL: site.url, description: site.metadata?.description, title: title)
                // TODO: make this red
                Button(action: { isDeleting = true }) {
                    Label("Remove", systemSymbol: .trash)
                }.foregroundColor(.red)
                if FeatureFlag[.pinToTopSites] {
                    Text("Pin/unpin not yet implemented")
                }
            }
            .actionSheet(isPresented: $isDeleting) {
                ActionSheet(
                    title: Text("Permanently remove \(title) from Suggested Sites?"),
                    buttons: [
                        .destructive(Text("Remove")) { zeroQueryHideTopSite(site) },
                        .cancel(),
                    ])
            }
        }
    }
}

struct SuggestedSitesView: View {
    let isExpanded: Bool
    @EnvironmentObject private var viewModel: SuggestedSitesViewModel
    @Environment(\.viewWidth) private var viewWidth

    var columnCount: Int {
        var columnCount = 0
        var excessSpace = viewWidth + SuggestedSiteUX.BlockSpacing
        while excessSpace > 0 {
            excessSpace -= SuggestedSiteUX.BlockSize + SuggestedSiteUX.BlockSpacing
            if excessSpace > 0 {
                columnCount += 1
            }
        }
        return columnCount
    }

    var body: some View {
        let columns = Array(
            repeating: GridItem(
                .fixed(SuggestedSiteUX.BlockSize), spacing: SuggestedSiteUX.BlockSpacing),
            count: columnCount)
        if isExpanded {
            LazyVGrid(columns: columns, alignment: .leading, spacing: SuggestedSiteUX.BlockSpacing)
            {
                ForEach(viewModel.sites, id: \.self) { suggestedSite in
                    SuggestedSiteView(
                        site: suggestedSite, isPinnedSite: suggestedSite is PinnedSite
                    )
                    .onDrag { NSItemProvider(url: suggestedSite.url) }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, ZeroQueryUX.Padding - 2)
        } else {
            FadingHorizontalScrollView { size in
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.sites.enumerated()), id: \.0) { i, suggestedSite in
                        if i > 0 {
                            Spacer().frame(width: SuggestedSiteUX.BlockSpacing)
                        }
                        SuggestedSiteView(
                            site: suggestedSite, isPinnedSite: suggestedSite is PinnedSite
                        )
                        .onDrag { NSItemProvider(url: suggestedSite.url) }
                    }
                }
                .frame(height: SuggestedSiteUX.BlockSize)
                .padding(.vertical, 10)
                .padding(.horizontal, ZeroQueryUX.Padding - 2)
                .fixedSize()
            }.frame(height: SuggestedSiteUX.BlockSize + 20)
        }
    }
}

#if DEBUG
    struct SuggestedSitesViews_Previews: PreviewProvider {
        static var previews: some View {
            HStack {
                SuggestedSiteView(
                    site: .init(url: "https://example.com", title: "Example", id: 1),
                    isPinnedSite: false)
                SuggestedSiteView(
                    site: .init(url: "https://google.com", title: "Google", id: 2),
                    isPinnedSite: true)
            }.padding().previewLayout(.sizeThatFits)
            Group {
                SuggestedSitesView(isExpanded: false)
                SuggestedSitesView(isExpanded: true)
            }
            .previewLayout(.sizeThatFits)
            .environment(\.viewWidth, 375)
            .environmentObject(SuggestedSitesViewModel.preview)
        }
    }
#endif
