// Shelve - Background Service Worker
// Handles communication between popup/content scripts and the local API

const DEFAULT_API_BASE = "http://localhost:9876";

async function getApiBase() {
    const result = await browser.storage.local.get("apiBase");
    return result.apiBase || DEFAULT_API_BASE;
}

browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.action === "saveToShelve") {
        getApiBase().then(apiBase =>
            saveItem(apiBase, message.data)
                .then(result => sendResponse(result))
                .catch(error => sendResponse({ status: "error", message: error.message }))
        );
        return true;
    }

    if (message.action === "checkStatus") {
        getApiBase().then(apiBase =>
            checkServerStatus(apiBase)
                .then(result => sendResponse(result))
                .catch(error => sendResponse({ status: "offline", message: error.message }))
        );
        return true;
    }

    if (message.action === "getSettings") {
        getApiBase().then(apiBase => sendResponse({ apiBase }));
        return true;
    }
});

async function saveItem(apiBase, data) {
    const response = await fetch(`${apiBase}/api/import`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
    });
    return await response.json();
}

async function checkServerStatus(apiBase) {
    const response = await fetch(`${apiBase}/api/status`, {
        signal: AbortSignal.timeout(3000),
    });
    return await response.json();
}
