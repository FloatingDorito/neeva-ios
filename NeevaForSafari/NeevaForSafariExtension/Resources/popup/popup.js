//
// Elements
const neevaRedirectToggle = document.getElementById("neevaRedirectToggle");
const cookieCutterToggle = document.getElementById("cookieCutterToggle");
const navigateToNeevaButton = document.getElementById("navigateToNeevaButton");

//
// Preference Keys
const neevaRedirectKey = "neevaRedirect";
const cookieCutterKey = "cookieCutter";

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
    savePreference(cookieCutterKey, cookieCutterToggle.checked);
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
