// Shelve - Content Script
// Runs on every page. Captures selected text when requested by popup.

browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.action === "getPageContext") {
        const context = {
            url: window.location.href,
            title: document.title,
            selection: window.getSelection().toString().trim(),
            referrer: document.referrer,
        };
        sendResponse(context);
    }
});
