"use strict";

import { CookieCategoryType, CookieEngine } from 'cookie-cutter';

var cookiePreferences = { marketing: false, analytic: false, social: false };

function setPreferences(preferences) {
    if (preferences["cookieCutterEnabled"]) {
        cookiePreferences["marketing"] = preferences["marketing"];
        cookiePreferences["analytic"] = preferences["analytic"];
        cookiePreferences["social"] = preferences["social"];
    
        runEngine();
    }
}

function runEngine() {
    // Not used by iOS.
    CookieEngine.flagSite(async () => {});

    // These are handled by the iOS app, can return default values.
    CookieEngine.isCookieConsentingEnabled(async () => true);
    CookieEngine.isFlaggedSite(async () => false);

    // Tell the iOS app to increase the count of cookies handled.
    CookieEngine.incrementCookieStats(async () => {
        browser.runtime.sendMessage({ cookieCutterUpdate: "increase-cookie-stats"});
    });

    // Tell the iOS app that a cookie notice has been handled.
    CookieEngine.notifyNoticeHandledOnPage(async () => {
        console.log("Notify notice handled on page");
        browser.runtime.sendMessage({ cookieCutterUpdate: "cookie-notice-handled"});
    });

    // Needed if the page is reloaded.
    CookieEngine.getHostname(() => window.location);

    //
    // User preferences, passed down from the iOS app.
    CookieEngine.areAllEnabled(async () => {
        return cookiePreferences["marketing"] && cookiePreferences["analytic"] && cookiePreferences["social"];
    });

    CookieEngine.isTypeEnabled(async (type) => {
        console.log("isTypeEnabled: " + type);
        switch (type) {
        case CookieCategoryType.Marketing:
        case CookieCategoryType.DoNotSell:
            return cookiePreferences.marketing;
        case CookieCategoryType.Analytics:
        case CookieCategoryType.Preferences:
            return cookiePreferences.analytic;
        case CookieCategoryType.Social:
        case CookieCategoryType.Unknown:
            return cookiePreferences.social;
        default:
            return false;
        }
    });

    //
    // TODO: Logging
    CookieEngine.logProviderUsage(async (provider) => {
        browser.runtime.sendMessage({ "cookieCutterUpdate": "log-provider-usage", provider: provider });
    });

    // Run!
    CookieEngine.runCookieCutter();

    console.log("started running");
    browser.runtime.sendMessage({ "cookieCutterUpdate": "started-running"});
}

console.log("get prefs");
browser.runtime.sendMessage({ "cookieCutterUpdate": "get-preferences" }).then((response) => {
    console.log(response);
    setPreferences(response);
});
