// Shelve - Settings Script

const DEFAULT_API_BASE = "http://localhost:9876";

document.addEventListener("DOMContentLoaded", async () => {
    const apiBaseField = document.getElementById("apiBase");
    const saveBtn = document.getElementById("saveBtn");
    const testBtn = document.getElementById("testBtn");
    const statusEl = document.getElementById("status");

    // Load saved settings
    const result = await browser.storage.local.get("apiBase");
    apiBaseField.value = result.apiBase || DEFAULT_API_BASE;

    saveBtn.addEventListener("click", async () => {
        const value = apiBaseField.value.trim().replace(/\/+$/, "");
        await browser.storage.local.set({ apiBase: value || DEFAULT_API_BASE });
        showStatus("Saved", "ok");
    });

    testBtn.addEventListener("click", async () => {
        const apiBase = apiBaseField.value.trim().replace(/\/+$/, "");
        showStatus("Testing...", "");
        try {
            const response = await fetch(`${apiBase}/api/status`, {
                signal: AbortSignal.timeout(3000),
            });
            const data = await response.json();
            if (data.status === "ok") {
                showStatus("Connected", "ok");
            } else {
                showStatus("Unexpected response", "fail");
            }
        } catch (e) {
            showStatus("Connection failed", "fail");
        }
    });

    function showStatus(text, className) {
        statusEl.textContent = text;
        statusEl.className = `status ${className}`;
    }
});
