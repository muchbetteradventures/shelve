// Shelve - Popup Script

let pageContext = {};

document.addEventListener("DOMContentLoaded", async () => {
    const statusDot = document.getElementById("statusDot");
    const offlineMsg = document.getElementById("offlineMsg");
    const mainContent = document.getElementById("mainContent");
    const pageTitle = document.getElementById("pageTitle");
    const pageUrl = document.getElementById("pageUrl");
    const selectionPreview = document.getElementById("selectionPreview");
    const saveBtn = document.getElementById("saveBtn");
    const resultDiv = document.getElementById("result");
    const annotationField = document.getElementById("annotation");
    const tagsField = document.getElementById("tags");

    // Settings links
    document.getElementById("settingsLink").addEventListener("click", () => {
        browser.runtime.openOptionsPage();
    });
    document.getElementById("offlineSettingsLink").addEventListener("click", () => {
        browser.runtime.openOptionsPage();
    });

    // Check server status
    try {
        const status = await browser.runtime.sendMessage({ action: "checkStatus" });
        if (status.status === "ok") {
            statusDot.classList.add("online");
        } else {
            showOffline();
            return;
        }
    } catch (e) {
        showOffline();
        return;
    }

    function showOffline() {
        statusDot.classList.add("offline");
        offlineMsg.classList.remove("hidden");
        mainContent.style.display = "none";
    }

    // Get page context by injecting a script on demand (only when popup is opened)
    try {
        const tabs = await browser.tabs.query({ active: true, currentWindow: true });
        if (tabs[0]) {
            const results = await browser.scripting.executeScript({
                target: { tabId: tabs[0].id },
                func: () => ({
                    url: window.location.href,
                    title: document.title,
                    selection: window.getSelection()?.toString()?.substring(0, 500) || "",
                    referrer: document.referrer,
                }),
            });
            pageContext = results[0]?.result || {
                url: tabs[0].url,
                title: tabs[0].title,
                selection: "",
                referrer: "",
            };
        }
    } catch (e) {
        // Fallback if scripting injection fails (e.g. on privileged pages)
        const tabs = await browser.tabs.query({ active: true, currentWindow: true });
        if (tabs[0]) {
            pageContext = {
                url: tabs[0].url,
                title: tabs[0].title,
                selection: "",
                referrer: "",
            };
        }
    }

    // Populate UI
    pageTitle.textContent = pageContext.title || "Untitled";
    pageUrl.textContent = pageContext.url || "";

    if (pageContext.selection) {
        selectionPreview.textContent = `"${pageContext.selection}"`;
        selectionPreview.classList.remove("hidden");
    }

    // Save button handler
    saveBtn.addEventListener("click", async () => {
        saveBtn.disabled = true;
        saveBtn.textContent = "Saving...";
        resultDiv.classList.add("hidden");

        const tags = tagsField.value
            .split(",")
            .map(t => t.trim().toLowerCase())
            .filter(t => t.length > 0);

        const data = {
            url: pageContext.url,
            title: pageContext.title,
            selection: pageContext.selection || "",
            referrer: pageContext.referrer || "",
            annotation: annotationField.value.trim(),
            tags: tags,
        };

        try {
            const result = await browser.runtime.sendMessage({
                action: "saveToShelve",
                data: data,
            });

            if (result.status === "created") {
                resultDiv.textContent = "Saved";
                resultDiv.className = "result success";
                saveBtn.textContent = "Saved";
            } else {
                resultDiv.textContent = result.message || "Something went wrong";
                resultDiv.className = "result error";
                saveBtn.textContent = "Shelve";
                saveBtn.disabled = false;
            }
        } catch (e) {
            resultDiv.textContent = "Failed to connect to API";
            resultDiv.className = "result error";
            saveBtn.textContent = "Shelve";
            saveBtn.disabled = false;
        }

        resultDiv.classList.remove("hidden");
    });

    annotationField.focus();
});
