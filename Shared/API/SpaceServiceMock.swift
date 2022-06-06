// Copyright 2022 Neeva Inc. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Apollo
import Combine
import Foundation

// TODO(jon): Implement this class once SpaceService is sandwiched
// between Apollo and higher layers
public class SpaceServiceMock: SpaceService {
    public typealias SpaceApollo = SpaceListController.Space
    public typealias SpaceDataApollo = SpacesDataQueryController.Space

    private struct SpaceMock {
        var space: SpaceApollo

        init(name: String) {
            space = SpaceApollo(
                pageMetadata: SpaceApollo.PageMetadatum(
                    pageId: name),
                space: SpaceApollo.Space(
                    name: name,
                    lastModifiedTs: ISO8601DateFormatter().string(from: Date()),
                    userAcl: SpaceApollo.Space.UserAcl(acl: SpaceACLLevel.owner),
                    resultCount: 0,
                    isDefaultSpace: false
                )
            )
        }
    }

    private struct SpaceDataMock {
        var spaceData: SpaceDataApollo

        init(name: String) {
            spaceData = SpaceDataApollo(
                id: name,
                name: name,
                entities: [],
                comments: [],
                generators: []
            )
        }
    }

    private var spaces: [String: SpaceMock] = [
        "My Space": SpaceMock(name: "My Space")
    ]
    private var spacesData: [String: SpaceDataMock] = [
        "My Space": SpaceDataMock(name: "My Space")
    ]

    public init() {}

    public func addPublicACL(spaceID: String) -> AddPublicACLRequest? {
        return nil
    }

    public func addSoloACLs(spaceID: String, emails: [String], acl: SpaceACLLevel, note: String)
        -> AddSoloACLsRequest?
    {
        return nil
    }

    public func addSpaceComment(spaceID: String, comment: String) -> AddSpaceCommentRequest? {
        return nil
    }

    public func addToSpaceMutation(
        spaceId: String, url: String, title: String,
        thumbnail: String?, data: String?, mediaType: String?, isBase64: Bool?,
        completion: @escaping (Result<AddToSpaceMutation.Data, Error>) -> Void
    ) -> Combine.Cancellable? {
        spacesData[spaceId]?.spaceData.entities.append(
            SpaceEntityData(
                id: url,
                url: URL(string: url),
                title: title,
                snippet: nil,
                thumbnail: nil,
                previewEntity: .webPage
            )
        )
        spaces[spaceId]?.space.space?.resultCount! += 1

        // Simulate a network request
        DispatchQueue.main.async {
            completion(
                Result<AddToSpaceMutation.Data, Error>(catching: {
                    return AddToSpaceMutation.Data(entityId: url)
                })
            )
        }

        return AnyCancellable {
            // do nothing
        }
    }

    public func addToSpaceWithURL(spaceID: String, url: String, title: String, description: String?)
        -> AddToSpaceWithURLRequest?
    {
        return nil
    }

    public func claimGeneratedItem(spaceID: String, entityID: String) -> ClaimGeneratedItem? {
        return nil
    }

    public func createSpace(name: String) -> CreateSpaceRequest? {
        spaces[name] = SpaceMock(name: name)
        spacesData[name] = SpaceDataMock(name: name)

        let request = CreateSpaceRequest()

        // Simulate a network request
        DispatchQueue.main.async {
            request.state = .success
        }

        return request
    }

    public func deleteGenerator(spaceID: String, generatorID: String) -> DeleteGeneratorRequest? {
        return nil
    }

    public func deletePublicACL(spaceID: String) -> DeletePublicACLRequest? {
        return nil
    }

    public func deleteSpace(spaceID: String) -> DeleteSpaceRequest? {
        return nil
    }

    public func deleteSpaceItems(spaceID: String, ids: [String]) -> DeleteSpaceItemsRequest? {
        return nil
    }

    public func getRelatedSpacesCountData(
        spaceID: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) -> Combine.Cancellable? {
        return nil
    }

    public func getRelatedSpacesData(
        spaceID: String,
        completion: @escaping (Result<[SpacesDataQueryController.Space], Error>) -> Void
    ) -> Combine.Cancellable? {
        return nil
    }

    public func getSpaces(
        completion: @escaping (Result<[SpaceApollo], Error>) -> Void
    ) -> Combine.Cancellable? {
        return AnyCancellable({ [self] in
            completion(
                Result<[SpaceApollo], Error>(catching: {
                    return spaces.map { $0.value.space }
                }))
        })
    }

    public func getSpacesData(
        spaceIds: [String],
        completion: @escaping (Result<[SpaceDataApollo], Error>) -> Void
    ) -> Combine.Cancellable? {
        return AnyCancellable({ [self] in
            completion(
                Result<[SpaceDataApollo], Error>(catching: {
                    var arr: [SpaceDataApollo] = []
                    spaceIds.forEach { id in
                        if let match = spacesData[id] {
                            arr.append(match.spaceData)
                        }
                    }
                    return arr
                })
            )
        })
    }

    public func reorderSpace(spaceID: String, ids: [String]) -> ReorderSpaceRequest? {
        return nil
    }

    public func unfollowSpace(spaceID: String) -> UnfollowSpaceRequest? {
        return nil
    }

    public func updateProfile(firstName: String, lastName: String) -> UpdateProfileRequest? {
        return nil
    }

    public func updateSpaceEntity(
        spaceID: String, entityID: String, title: String, snippet: String?, thumbnail: String?
    ) -> UpdateSpaceEntityRequest? {
        return nil
    }
}
