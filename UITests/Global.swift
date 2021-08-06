/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import GCDWebServers
import Storage
import SwiftKeychainWrapper
import WebKit

@testable import Client

let LabelAddressAndSearch = "Address and Search"

extension XCTestCase {
    func tester(_ file: String = #file, _ line: Int = #line) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self)
    }

    func system(_ file: String = #file, _ line: Int = #line) -> KIFSystemTestActor {
        return KIFSystemTestActor(inFile: file, atLine: line, delegate: self)
    }
}

extension KIFUITestActor {
    /// Looks for a view with the given accessibility hint.
    func tryFindingViewWithAccessibilityHint(_ hint: String) -> Bool {
        let element = UIApplication.shared.accessibilityElement { element in
            return element?.accessibilityHint! == hint
        }

        return element != nil
    }

    func waitForViewWithAccessibilityHint(_ hint: String) -> UIView? {
        var view: UIView? = nil
        autoreleasepool {
            wait(
                for: nil, view: &view,
                withElementMatching: NSPredicate(format: "accessibilityHint = %@", hint),
                tappable: false)
        }
        return view
    }

    func viewExistsWithLabel(_ label: String) -> Bool {
        do {
            try self.tryFindingView(withAccessibilityLabel: label)
            return true
        } catch {
            return false
        }
    }

    func viewExistsWithLabelPrefixedBy(_ prefix: String) -> Bool {
        let element = UIApplication.shared.accessibilityElement { element in
            return element?.accessibilityLabel?.hasPrefix(prefix) ?? false
        }
        return element != nil
    }

    /// Waits for and returns a view with the given accessibility value.
    func waitForViewWithAccessibilityValue(_ value: String) -> UIView {
        var element: UIAccessibilityElement!

        run { _ in
            element = UIApplication.shared.accessibilityElement { element in
                return element?.accessibilityValue == value
            }

            return (element == nil) ? KIFTestStepResult.wait : KIFTestStepResult.success
        }

        return UIAccessibilityElement.viewContaining(element)
    }

    /// Wait for and returns a view with the given accessibility label as an
    /// attributed string. See the comment in ReadingListPanel.swift about
    /// using attributed strings as labels. (It lets us set the pitch)
    func waitForViewWithAttributedAccessibilityLabel(_ label: NSAttributedString) -> UIView {
        var element: UIAccessibilityElement!

        run { _ in
            element = UIApplication.shared.accessibilityElement { element in
                if let elementLabel = element?.value(forKey: "accessibilityLabel")
                    as? NSAttributedString
                {
                    return elementLabel.isEqual(to: label)
                }
                return false
            }

            return (element == nil) ? KIFTestStepResult.wait : KIFTestStepResult.success
        }

        return UIAccessibilityElement.viewContaining(element)
    }

    /// There appears to be a KIF bug where waitForViewWithAccessibilityLabel returns the parent
    /// UITableView instead of the UITableViewCell with the given label.
    /// As a workaround, retry until KIF gives us a cell.
    /// Open issue: https://github.com/kif-framework/KIF/issues/336
    func waitForCellWithAccessibilityLabel(_ label: String) -> UITableViewCell {
        var cell: UITableViewCell!

        run { _ in
            let view = self.waitForView(withAccessibilityLabel: label)
            cell = view as? UITableViewCell
            return (cell == nil) ? KIFTestStepResult.wait : KIFTestStepResult.success
        }

        return cell
    }

    /// Finding views by accessibility label doesn't currently work with WKWebView:
    ///     https://github.com/kif-framework/KIF/issues/460
    /// As a workaround, inject a KIFHelper class that iterates the document and finds
    /// elements with the given textContent or title.
    func waitForWebViewElementWithAccessibilityLabel(
        _ text: String, timeout: TimeInterval = KIFTestActor.defaultTimeout()
    ) {
        run(
            { error in
                if self.hasWebViewElementWithAccessibilityLabel(text) {
                    return KIFTestStepResult.success
                }

                return KIFTestStepResult.wait
            }, timeout: timeout)
    }

    /// Sets the text for a WKWebView input element with the given name.
    func enterText(_ text: String, intoWebViewInputWithName inputName: String) {
        let webView = getWebViewWithKIFHelper()
        var stepResult = KIFTestStepResult.wait

        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        webView.evaluateJavascriptInDefaultContentWorld(
            "KIFHelper.enterTextIntoInputWithName(\"\(escaped)\", \"\(inputName)\");"
        ) { success, _ in
            stepResult =
                ((success as? Bool)!) ? KIFTestStepResult.success : KIFTestStepResult.failure
        }

        run { error in
            if stepResult == KIFTestStepResult.failure {
                error?.pointee = NSError(
                    domain: "KIFHelper", code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Input element not found in webview: \(escaped)"
                    ])
            }
            return stepResult
        }
    }

    /// Clicks a WKWebView element with the given label.
    func tapWebViewElementWithAccessibilityLabel(_ text: String) {
        let webView = getWebViewWithKIFHelper()
        var stepResult = KIFTestStepResult.wait

        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        webView.evaluateJavascriptInDefaultContentWorld(
            "KIFHelper.tapElementWithAccessibilityLabel(\"\(escaped)\")"
        ) { success, _ in
            stepResult =
                ((success as? Bool)!) ? KIFTestStepResult.success : KIFTestStepResult.failure
        }

        run { error in
            if stepResult == KIFTestStepResult.failure {
                error?.pointee = NSError(
                    domain: "KIFHelper", code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Accessibility label not found in webview: \(escaped)"
                    ])
            }
            return stepResult
        }
    }

    /// Determines whether an element in the page exists.
    func hasWebViewElementWithAccessibilityLabel(_ text: String) -> Bool {
        let webView = getWebViewWithKIFHelper()
        var stepResult = KIFTestStepResult.wait
        var found = false

        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        webView.evaluateJavascriptInDefaultContentWorld(
            "KIFHelper.hasElementWithAccessibilityLabel(\"\(escaped)\")"
        ) { success, _ in
            found = success as? Bool ?? false
            stepResult = KIFTestStepResult.success
        }

        run { _ in return stepResult }

        return found
    }

    fileprivate func getWebViewWithKIFHelper() -> WKWebView {
        let webView = waitForView(withAccessibilityLabel: "Web content") as! WKWebView

        // Wait for the web view to stop loading.
        run { _ in
            return webView.isLoading ? KIFTestStepResult.wait : KIFTestStepResult.success
        }
        var stepResult = KIFTestStepResult.wait

        webView.evaluateJavaScript("typeof KIFHelper") { result, _ in
            if result as! String == "undefined" {
                let bundle = Bundle(for: BundleHelper.self)
                let path = bundle.path(forResource: "KIFHelper", ofType: "js")!
                let source = try! String(contentsOfFile: path, encoding: .utf8)
                webView.evaluateJavaScript(source, completionHandler: nil)
            }
            stepResult = KIFTestStepResult.success
        }

        run { _ in return stepResult }

        return webView
    }

    public func deleteCharacterFromFirstResponser() {
        self.enterText(intoCurrentFirstResponder: "\u{0008}")
    }
}

private class BundleHelper {}

class BrowserUtils {
    // Needs to be in sync with Client Clearables.
    enum Clearable: String {
        case history = "Browsing History"
        case cache = "Cache"
        case cookies = "Cookies"
        case trackingProtection = "Tracking Protection"
        case downloads = "Downloaded Files"

        func label() -> String? {
            switch self {
            case .cookies:
                return "Cookies, Clearing it will sign you out of most sites."
            default:
                return self.rawValue
            }
        }
    }
    internal static let AllClearables = Set([
        Clearable.history, Clearable.cache, Clearable.cookies, Clearable.trackingProtection,
        Clearable.downloads,
    ])

    class func resetToAboutHomeKIF(_ tester: KIFUITestActor) {
        BrowserUtils.closeAllTabs(tester)
    }

    class func closeAllTabs(_ tester: KIFUITestActor) {
        tester.longPressView(withAccessibilityLabel: "Show Tabs", duration: 1)

        if tester.viewExistsWithLabel("Close All Tabs") {
            tester.tapView(withAccessibilityLabel: "Close All Tabs")
            tester.tapView(withAccessibilityLabel: "Confirm Close All Tabs")
        } else {
            tester.tapView(withAccessibilityIdentifier: "Close Tab Action")
        }
    }

    class func dismissFirstRunUI(_ tester: KIFUITestActor) {
        tester.waitForAnimationsToFinish(withTimeout: 3)
        tester.waitForAnimationsToFinish(withTimeout: 3)
        if tester.viewExistsWithLabel("Skip to browser without Neeva search") {
            tester.tapView(withAccessibilityLabel: "Skip to browser without Neeva search")
            tester.waitForAnimationsToFinish(withTimeout: 3)
            //tester.tapView(withAccessibilityIdentifier: "startBrowsingButtonSyncView")
        }
    }

    class func enterUrlAddressBar(_ tester: KIFUITestActor, typeUrl: String = "neeva.com") {
        if !tester.viewExistsWithLabel("Cancel") {
            tester.tapView(withAccessibilityLabel: "Address Bar")
        }

        tester.waitForView(withAccessibilityIdentifier: "address")
        tester.enterText(intoCurrentFirstResponder: typeUrl)
        tester.enterText(intoCurrentFirstResponder: "\n")
        tester.waitForAbsenceOfView(withAccessibilityIdentifier: "address")
    }

    class func getNumberOfTabs() -> Int {
        SceneDelegate.getTabManager().tabs.count
    }

    class func iPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    /// Injects a URL and title into the browser's history database.
    class func addHistoryEntry(_ title: String, url: URL) {
        let info: [AnyHashable: Any] = [
            "url": url,
            "title": title,
            "visitType": VisitType.link.rawValue,
        ]
        NotificationCenter.default.post(name: .OnLocationChange, object: self, userInfo: info)
    }

    fileprivate class func clearHistoryItemAtIndex(_ index: IndexPath, tester: KIFUITestActor) {
        if let row = tester.waitForCell(
            at: index, inTableViewWithAccessibilityIdentifier: "History List")
        {
            tester.swipeView(
                withAccessibilityLabel: row.accessibilityLabel, value: row.accessibilityValue,
                in: KIFSwipeDirection.left)
            tester.tapView(withAccessibilityLabel: "Remove")
        }
    }

    class func openClearPrivateDataDialogKIF(_ tester: KIFUITestActor) {
        openNeevaMenu(tester)
        tester.tapView(withAccessibilityIdentifier: "NeevaMenu.Settings")
        tester.accessibilityScroll(.down)

        tester.tapView(withAccessibilityLabel: "Clear Browsing Data")
    }

    class func closeClearPrivateDataDialog(_ tester: KIFUITestActor) {
        tester.tapView(withAccessibilityLabel: "Settings")
        tester.tapView(withAccessibilityLabel: "Done")
    }

    class func acceptClearPrivateData(_ tester: KIFUITestActor) {
        tester.tapView(withAccessibilityLabel: "Clear Data")
    }

    class func clearPrivateData(
        _ clearables: Set<Clearable>? = AllClearables, _ tester: KIFUITestActor
    ) {
        // Disable all items that we don't want to clear.
        tester.waitForAnimationsToFinish(withTimeout: 3)
        for clearable in AllClearables {
            tester.setOn(
                clearables!.contains(clearable), forSwitchWithAccessibilityLabel: clearable.label())
        }
        tester.tapView(withAccessibilityLabel: "Clear Selected Data on This Device")
    }

    class func clearPrivateDataKIF(_ tester: KIFUITestActor) {
        openNeevaMenu(tester)
        tester.waitForView(withAccessibilityIdentifier: "NeevaMenu.Settings")
        tester.tapView(withAccessibilityIdentifier: "NeevaMenu.Settings")
        tester.waitForAnimationsToFinish()
        tester.accessibilityScroll(.down)

        tester.waitForAnimationsToFinish()
        tester.tapView(withAccessibilityLabel: "Clear Browsing Data")
        tester.tapView(withAccessibilityLabel: "Clear Selected Data on This Device")

        acceptClearPrivateData(tester)
        closeClearPrivateDataDialog(tester)
    }

    class func clearHistoryItems(_ tester: KIFUITestActor, numberOfTests: Int = -1) {
        resetToAboutHomeKIF(tester)
        tester.tapView(withAccessibilityLabel: "History")

        let historyTable =
            tester.waitForView(withAccessibilityIdentifier: "History List") as! UITableView
        var index = 0
        for _ in 0..<historyTable.numberOfSections {
            for _ in 0..<historyTable.numberOfRows(inSection: 0) {
                clearHistoryItemAtIndex(IndexPath(row: 0, section: 0), tester: tester)
                if numberOfTests > -1 {
                    index += 1
                    if index == numberOfTests {
                        return
                    }
                }
            }
        }
        tester.tapView(withAccessibilityLabel: "Top sites")
    }

    class func ensureAutocompletionResult(
        _ tester: KIFUITestActor, textField: UITextField, prefix: String, completion: String
    ) {
        let autocompleteFieldlabel =
            textField.subviews.first { $0.accessibilityIdentifier == "autocomplete" } as? UILabel

        if completion == "" {
            XCTAssertTrue(
                autocompleteFieldlabel == nil,
                "The autocomplete was empty but the label still exists.")
            return
        }

        XCTAssertTrue(autocompleteFieldlabel != nil, "The autocomplete was not found")
        XCTAssertEqual(
            completion, autocompleteFieldlabel!.text, "Expected prefix matches actual prefix")
    }

    class func openNeevaMenu(_ tester: KIFUITestActor) {
        tester.waitForAnimationsToFinish()
        tester.waitForView(withAccessibilityLabel: "Neeva Menu")
        tester.tapView(withAccessibilityLabel: "Neeva Menu")
        tester.waitForAnimationsToFinish()
    }

    class func closeHistorySheet(_ tester: KIFUITestActor) {
        if tester.viewExistsWithLabel("History Panel") {
            let view = tester.waitForView(withAccessibilityIdentifier: "History Panel")
            view?.drag(from: CGPoint(x: 150, y: 30), to: CGPoint(x: 150, y: 530))
        } else if tester.viewExistsWithLabel("Done") {
            tester.waitForTappableView(withAccessibilityLabel: "Done")
            tester.tapView(withAccessibilityLabel: "Done")
        }

        tester.waitForAnimationsToFinish()
    }
}

class SimplePageServer {
    class func getPageData(_ name: String, ext: String = "html") -> String {
        let pageDataPath = Bundle(for: self).path(forResource: name, ofType: ext)!
        return try! String(contentsOfFile: pageDataPath, encoding: .utf8)
    }

    static var useLocalhostInsteadOfIP = false

    class func start() -> String {
        let webServer: GCDWebServer = GCDWebServer()

        webServer.addHandler(
            forMethod: "GET", path: "/image.png", request: GCDWebServerRequest.self
        ) { (request) -> GCDWebServerResponse? in
            let img = UIImage(named: "defaultFavicon")!.pngData()!
            return GCDWebServerDataResponse(data: img, contentType: "image/png")
        }

        for page in ["findPage", "noTitle", "readablePage", "JSPrompt", "blobURL", "neevaScheme"] {
            webServer.addHandler(
                forMethod: "GET", path: "/\(page).html", request: GCDWebServerRequest.self
            ) { (request) -> GCDWebServerResponse? in
                return GCDWebServerDataResponse(html: self.getPageData(page))
            }
        }

        // we may create more than one of these but we need to give them uniquie accessibility ids in the tab manager so we'll pass in a page number
        webServer.addHandler(
            forMethod: "GET", path: "/scrollablePage.html", request: GCDWebServerRequest.self
        ) { (request) -> GCDWebServerResponse? in
            var pageData = self.getPageData("scrollablePage")
            let page = Int(request.query!["page"]!)
            pageData = pageData.replacingOccurrences(of: "{page}", with: page!.description)
            return GCDWebServerDataResponse(html: pageData as String)
        }

        webServer.addHandler(
            forMethod: "GET", path: "/numberedPage.html", request: GCDWebServerRequest.self
        ) { (request) -> GCDWebServerResponse? in
            var pageData = self.getPageData("numberedPage")

            let page = Int(request.query!["page"]!)
            pageData = pageData.replacingOccurrences(of: "{page}", with: page!.description)

            return GCDWebServerDataResponse(html: pageData as String)
        }

        webServer.addHandler(
            forMethod: "GET", path: "/readerContent.html", request: GCDWebServerRequest.self
        ) { (request) -> GCDWebServerResponse? in
            return GCDWebServerDataResponse(html: self.getPageData("readerContent"))
        }

        webServer.addHandler(
            forMethod: "GET", path: "/loginForm.html", request: GCDWebServerRequest.self
        ) { _ in
            return GCDWebServerDataResponse(html: self.getPageData("loginForm"))
        }

        webServer.addHandler(
            forMethod: "GET", path: "/navigationDelegate.html", request: GCDWebServerRequest.self
        ) { _ in
            return GCDWebServerDataResponse(html: self.getPageData("navigationDelegate"))
        }

        webServer.addHandler(
            forMethod: "GET", path: "/localhostLoad.html", request: GCDWebServerRequest.self
        ) { _ in
            return GCDWebServerDataResponse(html: self.getPageData("localhostLoad"))
        }

        webServer.addHandler(
            forMethod: "GET", path: "/auth.html", request: GCDWebServerRequest.self
        ) { (request: GCDWebServerRequest?) in
            // "user:pass", Base64-encoded.
            let expectedAuth = "Basic dXNlcjpwYXNz"

            let response: GCDWebServerDataResponse
            if request?.headers["Authorization"] == expectedAuth && request?.query?["logout"] == nil
            {
                response = GCDWebServerDataResponse(html: "<html><body>logged in</body></html>")!
            } else {
                // Request credentials if the user isn't logged in.
                response = GCDWebServerDataResponse(html: "<html><body>auth fail</body></html>")!
                response.statusCode = 401
                response.setValue("Basic realm=\"test\"", forAdditionalHeader: "WWW-Authenticate")
            }

            return response
        }

        func htmlForImageBlockingTest(imageURL: String) -> String {
            let html =
                """
                <html><head><script>
                        function testImage(URL) {
                            var tester = new Image();
                            tester.onload = imageFound;
                            tester.onerror = imageNotFound;
                            tester.src = URL;
                            document.body.appendChild(tester);
                        }

                        function imageFound() {
                            alert('image loaded.');
                        }

                        function imageNotFound() {
                            alert('image not loaded.');
                        }

                        window.onload = function(e) {
                            // Disabling TP stats reporting using JS execution on the wkwebview happens async;
                            // setTimeout(1 sec) is plenty of delay to ensure the JS has executed.
                            setTimeout(() => { testImage('\(imageURL)'); }, 1000);
                        }
                    </script></head>
                <body>TEST IMAGE BLOCKING</body></html>
                """
            return html
        }

        // Add tracking protection check page
        webServer.addHandler(
            forMethod: "GET", path: "/tracking-protection-test.html",
            request: GCDWebServerRequest.self
        ) { (request: GCDWebServerRequest?) in
            return GCDWebServerDataResponse(
                html: htmlForImageBlockingTest(imageURL: "http://ymail.com/favicon.ico"))
        }

        // Add image blocking test page
        webServer.addHandler(
            forMethod: "GET", path: "/hide-images-test.html", request: GCDWebServerRequest.self
        ) { (request: GCDWebServerRequest?) in
            return GCDWebServerDataResponse(
                html: htmlForImageBlockingTest(imageURL: "https://www.mozilla.com/favicon.ico"))
        }

        if !webServer.start(withPort: 0, bonjourName: nil) {
            XCTFail("Can't start the GCDWebServer")
        }

        // We use 127.0.0.1 explicitly here, rather than localhost, in order to avoid our
        // history exclusion code (Bug 1188626).

        let webRoot =
            "http://\(useLocalhostInsteadOfIP ? "localhost" : "127.0.0.1"):\(webServer.port)"
        return webRoot
    }
}

// From iOS 10, below methods no longer works
class DynamicFontUtils {
    // Need to leave time for the notification to propagate
    static func bumpDynamicFontSize(_ tester: KIFUITestActor) {
        let value = UIContentSizeCategory.accessibilityExtraLarge
        UIApplication.shared.setValue(value, forKey: "preferredContentSizeCategory")
        tester.wait(forTimeInterval: 0.3)
    }

    static func lowerDynamicFontSize(_ tester: KIFUITestActor) {
        let value = UIContentSizeCategory.extraSmall
        UIApplication.shared.setValue(value, forKey: "preferredContentSizeCategory")
        tester.wait(forTimeInterval: 0.3)
    }

    static func restoreDynamicFontSize(_ tester: KIFUITestActor) {
        let value = UIContentSizeCategory.medium
        UIApplication.shared.setValue(value, forKey: "preferredContentSizeCategory")
        tester.wait(forTimeInterval: 0.3)
    }
}

class HomePageUtils {
    static func navigateToHomePageSettings(_ tester: KIFUITestActor) {
        tester.waitForAnimationsToFinish()
        tester.tapView(withAccessibilityLabel: "Neeva Menu")
        tester.tapView(withAccessibilityLabel: "Settings")
        tester.tapView(withAccessibilityIdentifier: "Homepage")
    }

    static func homePageSetting(_ tester: KIFUITestActor) -> String? {
        let view = tester.waitForView(withAccessibilityIdentifier: "HomeAsCustomURLTextField")
        guard let textField = view as? UITextField else {
            XCTFail("View is not a textField: view is \(String(describing: view))")
            return nil
        }
        return textField.text
    }

    static func navigateFromHomePageSettings(_ tester: KIFUITestActor) {
        tester.tapView(withAccessibilityLabel: "Settings")
        tester.tapView(withAccessibilityLabel: "Done")
    }
}

// see also `skipTest` in StorageTests and XCUITests
func skipTest(issue: Int, _ message: String) throws {
    throw XCTSkip("#\(issue): \(message)")
}
