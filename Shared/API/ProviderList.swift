// Copyright Neeva. All rights reserved.

import Apollo
import Foundation

public class ProviderList: ObservableObject {
    public static let shared = ProviderList()

    @Published public private(set) var isLoading = false
    @Published public private(set) var allProviders: [String: UserPreference] = [String: UserPreference]()

    public init() {}

    public func fetchProviderList() {
        isLoading = true
        GetAllProvidersQuery(input: .init(providerCategory: .recipes)).fetch { result in
            switch result {
            case .success(let data):
                if let providers = data.getAllProviders?.providers {
                    for provider in providers {
                        if let domain = provider.domain, let preference = provider.preference {
                            self.allProviders[domain] = preference
                        }

                    }
                }
            case .failure(let error):
                logger.error(error)
            }
            self.isLoading = false
        }
    }

    public func isListEmpty() -> Bool {
        return self.allProviders.count == 0
    }

    public func getPreferenceByDomain(domain: String) -> UserPreference {
        if allProviders.keys.contains(domain) {
            return allProviders[domain]!
        } else {
            fetchProviderList()
            return .noPreference
        }
    }
}
