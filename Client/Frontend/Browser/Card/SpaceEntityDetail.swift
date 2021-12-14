// Copyright Neeva. All rights reserved.

import Defaults
import SDWebImageSwiftUI
import Shared
import Storage
import SwiftUI

struct SpaceEntityDetailView: View {
    @Default(.showDescriptions) var showDescriptions
    @EnvironmentObject var spaceCardModel: SpaceCardModel
    let details: SpaceEntityThumbnail
    let onSelected: () -> Void
    let addToAnotherSpace: (URL, String?, String?) -> Void
    let editSpaceItem: () -> Void
    let index: Int

    var shouldHighlightAsUpdated: Bool {
        guard details.manager.id.id == SpaceStore.promotionalSpaceId else {
            return false
        }
        return spaceCardModel.updatedItemIDs.contains(details.id)
    }

    var socialURL: URL? {
        guard SocialInfoType(rawValue: details.data.url?.baseDomain ?? "") != nil else {
            return nil
        }

        return details.data.url
    }

    var titleToDisplay: String {
        switch details.data.previewEntity {
        case .richEntity(let richEntity):
            return richEntity.title
        case .retailProduct(let product):
            return product.title
        case .techDoc(let doc):
            return doc.title
        case .newsItem(let newsItem):
            return newsItem.title
        case .recipe(let recipe):
            return recipe.title
        case .webPage:
            return details.title
        }
    }

    var snippetToDisplay: String? {
        switch details.data.previewEntity {
        case .richEntity(let richEntity):
            return richEntity.description
        case .retailProduct(let product):
            return details.description ?? product.description.first
        case .newsItem(let newsItem):
            return newsItem.formattedDatePublished.capitalized + " - " + newsItem.snippet
        case .recipe(let _):
            return details.description
        case .techDoc(let doc):
            return doc.body?.string
        default:
            let searchPrefix = "](@"
            if let description = details.description, description.contains(searchPrefix) {
                let index = description.firstIndex(of: "@")
                var substring = description.suffix(from: index!)
                guard let endIndex = substring.firstIndex(of: ")") else {
                    return description
                }
                substring = substring[..<endIndex]
                return description.replacingOccurrences(
                    of: substring,
                    with: neevaSearchEngine.searchURLForQuery(String(substring))!.absoluteString)
            }
            return details.description
        }
    }

    @State private var isPressed: Bool = false
    @State private var isPreviewActive: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if index > 0 {
                Color.secondaryBackground.frame(height: 2).edgesIgnoringSafeArea(.top)
                Spacer(minLength: 0)
            }

            Button {
                onSelected()
                ClientLogger.shared.logCounter(
                    .SpacesDetailEntityClicked,
                    attributes: getLogCounterAttributesForSpaceEntities(details: details))
            } label: {
                if details.isImage, let url = details.data.url {
                    VStack(alignment: .leading, spacing: 6) {
                        WebImage(url: url).resizable()
                            .transition(.fade(duration: 0.5))
                            .background(Color.white)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(DetailsViewUX.ThumbnailCornerRadius)
                            .padding(.bottom, 8)
                        if !details.title.isEmpty {
                            Text(details.title)
                                .withFont(.bodyLarge)
                                .lineLimit(1)
                                .foregroundColor(Color.label)
                        }
                        if let domain = details.data.url?.baseDomain {
                            Text(domain)
                                .withFont(.bodySmall)
                                .lineLimit(1)
                                .foregroundColor(Color.secondaryLabel)
                        }
                    }
                } else {
                    VStack(spacing: DetailsViewUX.ItemPadding) {
                        HStack(alignment: .top, spacing: DetailsViewUX.ItemPadding) {
                            if case .techDoc(let _) = details.data.previewEntity {
                                EmptyView()
                            } else {
                                details.thumbnail.frame(
                                    width: DetailsViewUX.DetailThumbnailSize,
                                    height: DetailsViewUX.DetailThumbnailSize
                                )
                                .cornerRadius(DetailsViewUX.ThumbnailCornerRadius)
                            }
                            VStack(alignment: .leading, spacing: DetailsViewUX.Padding) {
                                HStack(spacing: 6) {
                                    if let socialURL = socialURL {
                                        FaviconView(forSiteUrl: socialURL)
                                            .frame(width: 12, height: 12)
                                            .cornerRadius(4)
                                    }
                                    Text(titleToDisplay)
                                        .withFont(.headingMedium)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .foregroundColor(.label)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                EntityInfoView(
                                    url: details.data.url!,
                                    entity: details.data.previewEntity
                                )
                                if !showDescriptions, #available(iOS 15.0, *),
                                    case .techDoc(let doc) = details.data.previewEntity,
                                    let body = doc.body
                                {
                                    Text(AttributedString(body))
                                        .withFont(.bodyLarge)
                                        .lineLimit(3)
                                        .modifier(DescriptionTextModifier())
                                } else if let snippet = snippetToDisplay,
                                    !showDescriptions, !snippet.isEmpty
                                {
                                    if #available(iOS 15.0, *),
                                        let attributedSnippet = try? AttributedString(
                                            markdown: snippet)
                                    {
                                        Text(attributedSnippet)
                                            .withFont(.bodyLarge)
                                            .lineLimit(3)
                                            .modifier(DescriptionTextModifier())
                                    } else {
                                        Text(snippet)
                                            .withFont(.bodyLarge)
                                            .lineLimit(3)
                                            .modifier(DescriptionTextModifier())
                                    }
                                }
                            }
                        }
                        if showDescriptions,
                            case .retailProduct(let product) = details.data.previewEntity,
                            let descriptions = product.description, !descriptions.isEmpty
                        {
                            ForEach(descriptions, id: \.self) { description in
                                Text(description)
                                    .withFont(.bodyLarge)
                                    .modifier(DescriptionTextModifier())
                            }
                        } else if showDescriptions, #available(iOS 15.0, *),
                            case .techDoc(let doc) = details.data.previewEntity, let body = doc.body
                        {
                            Text(AttributedString(body))
                                .withFont(.bodyLarge)
                                .modifier(DescriptionTextModifier())
                        } else if let snippet = snippetToDisplay,
                            showDescriptions, !snippet.isEmpty
                        {
                            if #available(iOS 15.0, *),
                                let attributedSnippet = try? AttributedString(markdown: snippet)
                            {
                                Text(attributedSnippet)
                                    .modifier(DescriptionTextModifier())
                            } else {
                                Text(snippet)
                                    .withFont(.bodyLarge)
                                    .modifier(DescriptionTextModifier())
                            }
                        } else if details.manager.ACL >= .edit,
                            snippetToDisplay?.isEmpty != false
                        {
                            Text("Click to add description")
                                .withFont(.bodyLarge)
                                .foregroundColor(.tertiaryLabel)
                                .highPriorityGesture(TapGesture().onEnded({ editSpaceItem() }))
                        }
                    }
                }
            }.buttonStyle(PressReportingButtonStyle(isPressed: $isPressed))
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    shouldHighlightAsUpdated
                        ? Color.ui.adaptive.blue.opacity(0.1) : Color.DefaultBackground)
            Spacer(minLength: 0)
        }.scaleEffect(isPressed ? 0.95 : 1)
            .contextMenu(
                ContextMenu(menuItems: {
                    if details.ACL >= .edit {
                        Button(
                            action: {
                                editSpaceItem()
                            },
                            label: {
                                Label("Edit item", systemSymbol: .squareAndPencil)
                            })
                    }
                    Button(
                        action: {
                            addToAnotherSpace(
                                (details.data.url)!,
                                details.title, details.description)
                        },
                        label: {
                            Label("Add to another Space", systemSymbol: .docOnDoc)
                        })
                })
            )
            .accessibilityLabel(details.title)
            .accessibilityHint("Space Item")
    }
}

private func getLogCounterAttributesForSpaceEntities(details: SpaceEntityThumbnail?)
    -> [ClientLogCounterAttribute]
{
    var attributes = EnvironmentHelper.shared.getAttributes()
    attributes.append(
        ClientLogCounterAttribute(
            key: LogConfig.SpacesAttribute.isPublic,
            value: String(details?.manager.isPublic ?? false)))
    if details?.isSharedPublic == true {
        attributes.append(
            ClientLogCounterAttribute(
                key: LogConfig.SpacesAttribute.spaceID,
                value: String(details?.spaceID ?? "")))
        attributes.append(
            ClientLogCounterAttribute(
                key: LogConfig.SpacesAttribute.spaceEntityID,
                value: String(details?.id ?? "")))
    }
    attributes.append(
        ClientLogCounterAttribute(
            key: LogConfig.SpacesAttribute.isShared,
            value: String(details?.manager.isShared ?? false)))
    attributes.append(
        ClientLogCounterAttribute(
            key: LogConfig.SpacesAttribute.numberOfSpaceEntities,
            value: String(details?.manager.contentData?.count ?? 1)
        )

    )
    return attributes
}

struct DescriptionTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .foregroundColor(Color.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
