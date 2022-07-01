//
// Elements
const neevaRedirectToggle = document.getElementById("neevaRedirectToggle");

// Cookie Cutter
const cookieCutterToggle = document.getElementById("cookieCutterToggle");
const cookieCutterSettingsSection = document.getElementById("cookieCutterSettings");
const acceptCookiesPicker = document.getElementById("acceptCookiesPicker");
const declineCookiesPicker = document.getElementById("declineCookiesPicker");

const navigateToNeevaButton = document.getElementById("navigateToNeevaButton");

//
// Preference Keys
const neevaRedirectKey = "neevaRedirect";
const cookieCutterKey = "cookieCutter";
const acceptCookiesKey = "acceptCookies";

function savePreference(preferenceName, value) {
    browser.runtime.sendMessage({ "savePreference": preferenceName, "value": value });
};

function setPreference(preferenceName, toggle) {
    browser.runtime.sendMessage({ "getPreference": preferenceName }).then((response) => {
        toggle.checked = response["value"];
    });
};

//
// Toggles
neevaRedirectToggle.onclick = function() {
    savePreference(neevaRedirectKey, neevaRedirectToggle.checked);
};

cookieCutterToggle.onclick = function() {
    updateCookieCutterSettingsDisplayState();
    savePreference(cookieCutterKey, cookieCutterToggle.checked);
};

//
// Cookie Cutter settings
acceptCookiesPicker.onclick = function() {
    declineCookiesPicker.checked = !acceptCookiesPicker.checked;
    savePreference(acceptCookiesKey, acceptCookiesPicker.checked);
};

declineCookiesPicker.onclick = function() {
    acceptCookiesPicker.checked = !declineCookiesPicker.checked;
    savePreference(acceptCookiesKey, declineCookiesPicker.checked); 
};

function updateCookieCutterSettingsDisplayState() {
    cookieCutterSettingsSection.style.display = cookieCutterToggle.checked ? "block" : "none";
};

//
// Buttons
navigateToNeevaButton.onclick = function() {
    window.open("https://neeva.com");
};

// This code was used to open the Neeva app store page when we had a button for it in the extension.
// Leaving it here in case we need it sometime in the future.
// document.getElementById("downloadNeevaAppButton").onclick = function() {
//     window.open("https://apps.apple.com/us/app/neeva-browser-search-engine/id1543288638");
// };

//
// On Run
setPreference(neevaRedirectKey, neevaRedirectToggle);
setPreference(cookieCutterKey, cookieCutterToggle);
updateCookieCutterSettingsDisplayState();
