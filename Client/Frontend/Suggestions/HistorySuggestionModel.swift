/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Combine
import Foundation
import Shared
import Storage
import XCGLogger

private let log = Logger.browser

private let URLBeforePathRegex = try! NSRegularExpression(
    pattern: "^https?://([^/]+)/", options: [])

private let defaultRecencyDuration: UInt64 = 2 * OneDayInMilliseconds * 1000
private let numSuggestionsToFetch: Int = 40

/// Shared data source for the SearchViewController and the URLBar domain completion.
/// Since both of these use the same SQL query, we can perform the query once and dispatch the results.
class HistorySuggestionModel: ObservableObject {
    private let frecentHistory: FrecentHistory
    private let queryModel: SearchQueryModel

    /// If `completion` is non-`nil`, `SearchQueryModel.shared.value + completion` is the suggested completion.
    @Published private(set) var completion: String?
    @Published private(set) var sites: [Site]?
    @Published private(set) var recentSites: [Site]?

    private var shouldSkipNextAutocomplete = false

    convenience init(
        previewSites: [Site]? = nil, previewCompletion: String? = nil,
        queryModel: SearchQueryModel = SearchQueryModel(previewValue: "")
    ) {
        self.init(profile: BrowserProfile(localName: "profile"), queryModel: queryModel)
        self.sites = previewSites
        self.completion = previewCompletion
    }

    init(profile: Profile, queryModel: SearchQueryModel) {
        self.frecentHistory = profile.history.getFrecentHistory()
        self.queryModel = queryModel
        subscribe()
    }

    @discardableResult func clearCompletion() -> Bool {
        let cleared = completion != nil
        completion = nil
        return cleared
    }

    func skipNextAutocomplete() {
        shouldSkipNextAutocomplete = true
    }

    func setQueryWithoutAutocomplete(_ query: String) {
        skipNextAutocomplete()
        queryModel.value = query
    }

    fileprivate lazy var topDomains: [String] = {
        let filePath = Bundle.main.path(forResource: "topdomains", ofType: "txt")
        return try! String(contentsOfFile: filePath!).components(separatedBy: "\n")
    }()

    // `weak` usage here allows deferred queue to be the owner. The deferred is always filled and this set to nil,
    // this is defensive against any changes to queue (or cancellation) behaviour in future.
    private weak var currentDeferredHistoryQuery: CancellableDeferred<Maybe<Cursor<Site?>>>?

    private var searchTextSubscription: AnyCancellable?

    private func subscribe() {
        searchTextSubscription = queryModel.$value.withPrevious().sink {
            [unowned self] oldQuery, query in
            currentDeferredHistoryQuery?.cancel()

            if query.isEmpty {
                sites = []
                completion = nil
                shouldSkipNextAutocomplete = false
                return
            }

            guard
                let deferredHistory = frecentHistory.getSites(
                    matchingSearchQuery: query, limit: numSuggestionsToFetch)
                    as? CancellableDeferred
            else {
                assertionFailure("FrecentHistory query should be cancellable")
                return
            }

            currentDeferredHistoryQuery = deferredHistory

            deferredHistory.uponQueue(.main) { result in
                defer {
                    self.currentDeferredHistoryQuery = nil
                }

                guard !deferredHistory.cancelled else {
                    return
                }

                // Exclude Neeva search url suggestions from history suggest, since they should
                // readily be coming as query suggestions.
                let deferredHistorySites = (result.successValue?.asArray() ?? [])
                    .compactMap { $0 }
                    .filter {
                        !($0.url.absoluteString.hasPrefix(
                            NeevaConstants.appSearchURL.absoluteString))
                    }

                // Split the data to frequent visits from recent history and everything else
                self.recentSites =
                    deferredHistorySites
                    .filter {
                        $0.latestVisit != nil
                            && $0.latestVisit!.date > Date.nowMicroseconds()
                                - defaultRecencyDuration
                    }
                self.sites =
                    deferredHistorySites
                    .filter {
                        $0.latestVisit == nil
                            || $0.latestVisit!.date <= Date.nowMicroseconds()
                                - defaultRecencyDuration
                    }

                // If we should skip the next autocomplete, reset
                // the flag and bail out here.
                guard !self.shouldSkipNextAutocomplete else {
                    self.shouldSkipNextAutocomplete = false
                    return
                }

                let query = query.stringByTrimmingLeadingCharactersInSet(.whitespaces)

                // First, see if the query matches any URLs from the user's search history.
                for site in deferredHistorySites {
                    if setCompletion(to: completionForURL(site.url, from: query), from: query) {
                        return
                    }
                }

                // If there are no search history matches, try matching one of the Alexa top domains.
                for domain in self.topDomains {
                    if setCompletion(to: completionForDomain(domain, from: query), from: query) {
                        return
                    }
                }

                if self.completion != nil {
                    self.completion = nil
                }
            }
        }
    }

    private func setCompletion(to completion: String?, from query: String) -> Bool {
        if let completion = completion, completion != query {
            precondition(
                completion.lowercased().starts(with: query.lowercased()),
                "Expected completion '\(completion)' to start with '\(query)'")
            self.completion = String(completion.dropFirst(query.count))
            return true
        }
        return false
    }

    fileprivate func completionForURL(_ url: URL, from query: String) -> String? {
        let url = url.absoluteString as NSString
        // Extract the pre-path substring from the URL. This should be more efficient than parsing via
        // NSURL since we need to only look at the beginning of the string.
        // Note that we won't match non-HTTP(S) URLs.
        guard
            let match = URLBeforePathRegex.firstMatch(
                in: url as String, options: [], range: NSRange(location: 0, length: url.length))
        else {
            return nil
        }

        // If the pre-path component (including the scheme) starts with the query, just use it as is.
        var prePathURL = url.substring(with: match.range(at: 0))
        if prePathURL.hasPrefix(query) {
            // Trailing slashes in the autocompleteTextField cause issues with Swype keyboard. Bug 1194714
            if prePathURL.hasSuffix("/"), !query.hasSuffix("/") {
                prePathURL.remove(at: prePathURL.index(before: prePathURL.endIndex))
            }
            return prePathURL
        }

        // Otherwise, find and use any matching domain.
        // To simplify the search, prepend a ".", and search the string for ".query".
        // For example, for http://en.m.wikipedia.org, domainWithDotPrefix will be ".en.m.wikipedia.org".
        // This allows us to use the "." as a separator, so we can match "en", "m", "wikipedia", and "org",
        let domain = (url as NSString).substring(with: match.range(at: 1))
        return completionForDomain(domain, from: query)
    }

    fileprivate func completionForDomain(_ domain: String, from query: String) -> String? {
        let domainWithDotPrefix: String = ".\(domain)"
        if let range = domainWithDotPrefix.range(
            of: ".\(query)", options: .caseInsensitive, range: nil, locale: nil)
        {
            let matchedDomain = String(
                domainWithDotPrefix[domainWithDotPrefix.index(range.lowerBound, offsetBy: 1)...])
            // We don't actually want to match the top-level domain ("com", "org", etc.) by itself, so
            // so make sure the result includes at least one ".".
            if matchedDomain.contains(".") {
                return matchedDomain
            }
        }

        return nil
    }
}
