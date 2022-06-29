// Inject the Cookie Cutter script into the webpage.
const scriptUrl = browser.runtime.getURL('scripts/cookieCutterEngine.js');
const element = document.createElement('script');
element.src = scriptUrl;
document.head.appendChild(element);

// Add a listner to pass messages from the Cookie Cutter script
// to the SafariWebExtensionHandler.
window.addEventListener("cookie-cutter-update", function(event) {
    let data = event.detail;
    
    browser.runtime.sendMessage(data).then((response) => {
        window.dispatchEvent(new CustomEvent('cookie-cutter-update-response', { 
            detail: { respondingTo: data.cookieCutterUpdate, response: response }
        }));
    }); 
}, false);
