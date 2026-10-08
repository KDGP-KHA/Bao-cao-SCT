(function () {
    "use strict";
    var host = document.getElementById("sct-chatbot");
    if (!host) return;
    var loader = null;
    var expiryTimer = null;
    var controller = null;
    var stopped = false;
    var generation = 0;

    function unavailable() {
        if (stopped) return;
        var status = host.querySelector('[role="status"]');
        if (!status) {
            status = document.createElement("p");
            status.className = "alert alert-warning";
            status.setAttribute("role", "status");
            host.appendChild(status);
        }
        status.textContent = "Chatbot hiện không khả dụng. Đang thử kết nối lại…";
        host.hidden = false;
        expiryTimer = window.setTimeout(start, 30000);
    }

    function logout() {
        stopped = true;
        destroy();
        host.hidden = true;
        try { localStorage.setItem("sct-chatbot-logout", String(Date.now())); } catch (error) { /* Storage may be disabled. */ }
    }

    function isLogout(target) {
        var url = new URL(target, window.location.href);
        return url.origin === window.location.origin && /\/Account\/Logout\/?$/i.test(url.pathname);
    }

    function destroy() {
        generation += 1;
        window.clearTimeout(expiryTimer);
        if (controller) controller.abort();
        if (loader) {
            window.dispatchEvent(new CustomEvent("vnpt-chat-widget:destroy", { detail: { scriptSrc: loader.src } }));
            loader.remove();
            loader = null;
        }
    }

    async function start() {
        destroy();
        if (stopped) return;
        var currentGeneration = generation;
        var sessionController = new AbortController();
        controller = sessionController;
        var timeout = window.setTimeout(function () { sessionController.abort(); }, 12000);
        try {
            var response = await fetch(host.dataset.sessionUrl, {
                method: "POST",
                credentials: "same-origin",
                cache: "no-store",
                headers: {
                    "Accept": "application/json",
                    "X-CSRF-Token": host.querySelector('input[name="__RequestVerificationToken"]').value
                },
                signal: sessionController.signal
            });
            if (response.status === 401 || response.status === 403) stopped = true;
            if (!response.ok) throw new Error("Chatbot session could not be created.");
            var session = await response.json();
            var remaining = Date.parse(session.expiresAt) - Date.now();
            if (!session.viewerToken || !Number.isFinite(remaining) || remaining <= 0) throw new Error("Invalid Chatbot session.");
            if (stopped || currentGeneration !== generation) return;
            loader = document.createElement("script");
            loader.type = "module";
            // Re-evaluate the module for every new viewer session; never put tokens in URLs or storage.
            var url = new URL(host.dataset.loaderUrl);
            url.searchParams.set("sctSession", String(Date.now()));
            loader.src = url.href;
            loader.async = true;
            loader.dataset.viewerToken = session.viewerToken;
            loader.onerror = function () {
                if (stopped || currentGeneration !== generation) return;
                destroy(); unavailable();
            };
            host.hidden = true;
            document.body.appendChild(loader);
            expiryTimer = window.setTimeout(start, Math.max(1, Math.floor(remaining * 0.8)));
        } catch (error) {
            if (currentGeneration === generation && !stopped) unavailable();
        } finally {
            window.clearTimeout(timeout);
        }
    }

    document.addEventListener("click", function (event) {
        var anchor = event.target.closest && event.target.closest("a[href]");
        if (!anchor) return;
        if (isLogout(anchor.href)) logout();
    });
    document.addEventListener("submit", function (event) {
        if (event.target && isLogout(event.target.action)) logout();
    });
    window.addEventListener("storage", function (event) {
        if (event.key === "sct-chatbot-logout") { stopped = true; destroy(); host.hidden = true; }
    });
    window.addEventListener("pagehide", function () { stopped = true; destroy(); });
    window.addEventListener("pageshow", function (event) {
        if (event.persisted) { stopped = false; start(); }
    });
    start();
}());
