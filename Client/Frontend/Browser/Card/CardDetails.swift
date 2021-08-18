// Copyright Neeva. All rights reserved.

import Combine
import Foundation
import SDWebImageSwiftUI
import Shared
import Storage
import SwiftUI

protocol SelectableThumbnail {
    associatedtype ThumbnailView: View

    var thumbnail: ThumbnailView { get }
    func onSelect()
}

protocol CardDetails: ObservableObject, DropDelegate, SelectableThumbnail {
    associatedtype Item: BrowserPrimitive
    associatedtype FaviconViewType: View

    var id: String { get }
    var closeButtonImage: UIImage? { get }
    var title: String { get }
    var accessibilityLabel: String { get }
    var favicon: FaviconViewType { get }
    var isSelected: Bool { get }
    var thumbnailDrawsHeader: Bool { get }

    func onClose()
}

extension CardDetails {
    var isSelected: Bool {
        false
    }

    func performDrop(info: DropInfo) -> Bool {
        return false
    }

    var thumbnailDrawsHeader: Bool {
        true
    }
}

extension CardDetails
where
    Item: Selectable, Self: SelectingManagerProvider, Self.Manager.Item == Item,
    Manager: AccessingManager
{

    func onSelect() {
        if let item = manager.get(for: id) {
            manager.select(item)
        }
    }
}

extension CardDetails
where
    Item: Closeable, Self: ClosingManagerProvider, Self.Manager.Item == Item,
    Manager: AccessingManager
{

    var closeButtonImage: UIImage? {
        UIImage(systemName: "xmark")
    }

    func onClose() {
        if let item = manager.get(for: id) {
            manager.close(item)
        }
    }
}

extension CardDetails where Self: AccessingManagerProvider, Self.Manager.Item == Item {
    var title: String {
        manager.get(for: id)?.displayTitle ?? ""
    }

    @ViewBuilder var thumbnail: some View {
        if let image = manager.get(for: id)?.image {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            Color.white
        }
    }

    @ViewBuilder var favicon: some View {
        if let item = manager.get(for: id) {
            if let favIcon = item.displayFavicon {
                WebImage(url: favIcon.url)
                    .resizable()
                    .transition(.fade(duration: 0.5)).background(Color.white)
                    .scaledToFit()
            } else if let url = item.primitiveUrl {
                FaviconView(url: url, size: SuggestionViewUX.FaviconSize, bordered: false)
            }
        }
    }
}

public class TabCardDetails: CardDetails, AccessingManagerProvider,
    ClosingManagerProvider, SelectingManagerProvider
{
    typealias Item = Tab
    typealias Manager = TabManager

    var id: String
    var manager: TabManager

    var url: URL? {
        manager.get(for: id)?.url
    }

    var isSelected: Bool {
        self.manager.selectedTab?.tabUUID == id
    }

    var accessibilityLabel: String {
        "\(title), Tab"
    }

    var thumbnailDrawsHeader: Bool {
        false
    }

    // Avoiding keeping a reference to classes both to minimize surface area these Card classes have
    // access to, but also to not worry about reference copying while using CardDetails for View updates.
    init(tab: Tab, manager: TabManager) {
        self.id = tab.id
        self.manager = manager
    }

    public func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: ["public.url"]) else {
            return false
        }

        let items = info.itemProviders(for: ["public.url"])
        for item in items {
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        self.manager.get(for: self.id)?.loadRequest(URLRequest(url: url))
                    }
                }
            }
        }

        return true
    }
}

struct SpaceEntityThumbnail: SelectableThumbnail {
    let data: SpaceEntityData
    let selected: () -> Void

    @ViewBuilder var thumbnail: some View {
        if let thumbnailData = data.thumbnail?.dataURIBody {
            Image(uiImage: UIImage(data: thumbnailData)!)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            FaviconView(url: data.url, size: .infinity, bordered: false)
        }
    }

    func onSelect() {
        selected()
    }
}

class SpaceCardDetails: CardDetails, AccessingManagerProvider, ThumbnailModel {
    typealias Item = Space
    typealias Manager = SpaceStore
    typealias Thumbnail = SpaceEntityThumbnail

    @Published var manager = SpaceStore.shared
    var id: String
    var closeButtonImage: UIImage? = nil
    var allDetails: [SpaceEntityThumbnail] = []

    var accessibilityLabel: String {
        "\(title), Space"
    }

    var space: Space? {
        manager.get(for: id)
    }

    private init(id: String) {
        self.id = id
        updateDetails()
    }

    convenience init(space: Space) {
        self.init(id: space.id.id)
    }

    var thumbnail: some View {
        VStack(spacing: 0) {
            ThumbnailGroupView(model: self)
            HStack {
                Spacer(minLength: 12)
                Text(title)
                    .withFont(.labelMedium)
                    .lineLimit(1)
                    .foregroundColor(Color.label)
                    .frame(height: CardUX.HeaderSize)
                if let space = space, space.isPublic {
                    Symbol(decorative: .link, style: .labelMedium)
                        .foregroundColor(.secondaryLabel)
                } else if let space = space, space.isShared {
                    Symbol(decorative: .person2Fill, style: .labelMedium)
                        .foregroundColor(.secondaryLabel)
                }
                Spacer(minLength: 12)
            }
        }.shadow(radius: 0)
    }

    func updateDetails() {
        allDetails =
            manager.get(for: id)?.contentData?
            .sorted(by: { first, second in first.thumbnail?.dataURIBody != nil })
            .map { SpaceEntityThumbnail(data: $0, selected: {}) } ?? []
    }

    func onSelect() {
        guard let url = manager.get(for: id)?.primitiveUrl else {
            return
        }

        SceneDelegate.getBVC().switchToTabForURLOrOpen(url)
    }

    func onClose() {}

    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: ["public.text", "public.url"]) else {
            return false
        }

        var items = info.itemProviders(for: ["public.url"])
        let foundUrl = !items.isEmpty
        for item in items {
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, let space = self.manager.get(for: self.id) {
                    DispatchQueue.main.async {
                        let request = AddToSpaceRequest(
                            title: "Link from \(url.baseDomain ?? "page")",
                            description: "", url: url)
                        request.addToExistingSpace(id: space.id.id, name: space.name)

                        ToastDefaults().showToastForSpace(request: request)
                    }
                }
            }
        }

        guard !foundUrl else {
            return true
        }

        items = info.itemProviders(for: ["public.text"])
        for item in items {
            _ = item.loadObject(ofClass: String.self) { text, _ in
                if let text = text, let space = self.manager.get(for: self.id) {
                    DispatchQueue.main.async {
                        let bvc = SceneDelegate.getBVC()
                        let request = AddToSpaceRequest(
                            title: "Selected snippets",
                            description: text,
                            url: (bvc.tabManager.selectedTab?.url)!)
                        request.addToExistingSpace(id: space.id.id, name: space.name)

                        ToastDefaults().showToastForSpace(request: request)
                    }
                }
            }
        }

        return true
    }
}

class SiteCardDetails: CardDetails, AccessingManagerProvider {
    typealias Item = Site
    typealias Manager = SiteFetcher

    @Published var manager: SiteFetcher
    var anyCancellable: AnyCancellable? = nil
    var id: String
    var closeButtonImage: UIImage?

    var accessibilityLabel: String {
        "\(title), Link"
    }

    init(url: URL, profile: Profile, fetcher: SiteFetcher) {
        self.id = url.absoluteString
        self.manager = fetcher
        self.anyCancellable = fetcher.objectWillChange.sink { [weak self] (_) in
            self?.objectWillChange.send()
        }
        fetcher.load(url: url, profile: profile)
    }

    func thumbnail(size: CGFloat) -> some View {
        return WebImage(
            url:
                URL(string: manager.get(for: id)?.pageMetadata?.mediaURL ?? "")
        )
        .resizable().aspectRatio(contentMode: .fill)
    }

    func onSelect() {
        guard let site = manager.get(for: id) else {
            return
        }

        SceneDelegate.getTabManager().selectedTab?.select(site)
    }

    func onClose() {}
}

class TabGroupCardDetails: CardDetails, AccessingManagerProvider, ClosingManagerProvider,
    ThumbnailModel
{
    typealias Item = TabGroup
    typealias Manager = TabGroupManager

    var manager: TabGroupManager
    var id: String
    var isSelected: Bool {
        manager.tabManager.selectedTab?.rootUUID == id
    }
    @Published var allDetails: [TabCardDetails] = []

    var accessibilityLabel: String {
        "\(title), Tab Group"
    }

    init(tabGroup: TabGroup, tabGroupManager: TabGroupManager) {
        self.id = tabGroup.id
        self.manager = tabGroupManager
        allDetails =
            manager.get(for: id)?.children
            .map({ TabCardDetails(tab: $0, manager: manager.tabManager) }) ?? []
    }

    var thumbnail: some View {
        return ThumbnailGroupView(model: self)
    }

    func onSelect() {}
}
