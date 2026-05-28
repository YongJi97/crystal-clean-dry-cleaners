/* =========================================================================
   Crystal Clean Dry Cleaners — shared site interactions (vanilla JS)
   ========================================================================= */
(function () {
    "use strict";

    /* ---------------------------------------------- Sticky header shadow */
    var header = document.querySelector(".site-header");
    if (header) {
        var onScroll = function () {
            header.classList.toggle("is-scrolled", window.scrollY > 8);
        };
        onScroll();
        window.addEventListener("scroll", onScroll, { passive: true });
    }

    /* ------------------------------------------------- Active nav links */
    var current = window.location.pathname.split("/").pop() || "index.html";
    if (current === "") current = "index.html";
    document.querySelectorAll("[data-nav]").forEach(function (link) {
        var href = (link.getAttribute("href") || "").split("#")[0].split("/").pop();
        if (href === current) {
            link.classList.add("active");
            link.setAttribute("aria-current", "page");
        }
    });

    /* ---------------------------------------------------- Mobile drawer */
    var toggle = document.querySelector(".nav-toggle");
    var drawer = document.querySelector(".nav-drawer");
    var backdrop = document.querySelector(".nav-drawer-backdrop");
    var closeBtn = document.querySelector(".nav-drawer-close");

    function openDrawer() {
        if (!drawer) return;
        drawer.classList.add("open");
        if (backdrop) backdrop.classList.add("open");
        if (toggle) toggle.setAttribute("aria-expanded", "true");
        document.body.style.overflow = "hidden";
    }
    function closeDrawer() {
        if (!drawer) return;
        drawer.classList.remove("open");
        if (backdrop) backdrop.classList.remove("open");
        if (toggle) toggle.setAttribute("aria-expanded", "false");
        document.body.style.overflow = "";
    }
    if (toggle) toggle.addEventListener("click", openDrawer);
    if (closeBtn) closeBtn.addEventListener("click", closeDrawer);
    if (backdrop) backdrop.addEventListener("click", closeDrawer);
    if (drawer) {
        drawer.querySelectorAll("a").forEach(function (a) {
            a.addEventListener("click", closeDrawer);
        });
    }
    document.addEventListener("keydown", function (e) {
        if (e.key === "Escape") closeDrawer();
    });

    /* ----------------------------------------------------- Scroll reveal */
    var revealEls = document.querySelectorAll(".reveal");
    if ("IntersectionObserver" in window && revealEls.length) {
        var io = new IntersectionObserver(
            function (entries) {
                entries.forEach(function (entry) {
                    if (entry.isIntersecting) {
                        entry.target.classList.add("in");
                        io.unobserve(entry.target);
                    }
                });
            },
            { threshold: 0.12, rootMargin: "0px 0px -60px 0px" }
        );
        revealEls.forEach(function (el) {
            io.observe(el);
        });
    } else {
        revealEls.forEach(function (el) {
            el.classList.add("in");
        });
    }

    /* -------------------------------------------------------- Accordion */
    document.querySelectorAll(".acc-trigger").forEach(function (btn) {
        btn.addEventListener("click", function () {
            var item = btn.closest(".acc-item");
            var panel = item.querySelector(".acc-panel");
            var isOpen = item.classList.contains("open");

            // close siblings within the same accordion
            var group = item.closest(".accordion");
            if (group) {
                group.querySelectorAll(".acc-item.open").forEach(function (other) {
                    if (other !== item) {
                        other.classList.remove("open");
                        other.querySelector(".acc-panel").style.maxHeight = null;
                        other
                            .querySelector(".acc-trigger")
                            .setAttribute("aria-expanded", "false");
                    }
                });
            }

            if (isOpen) {
                item.classList.remove("open");
                panel.style.maxHeight = null;
                btn.setAttribute("aria-expanded", "false");
            } else {
                item.classList.add("open");
                panel.style.maxHeight = panel.scrollHeight + "px";
                btn.setAttribute("aria-expanded", "true");
            }
        });
    });

    /* --------------------------------------------------------- Lightbox */
    var lightbox = document.querySelector(".lightbox");
    if (lightbox) {
        var lbImg = lightbox.querySelector("img");
        var lbClose = lightbox.querySelector(".lightbox-close");
        function openLightbox(src, alt) {
            lbImg.src = src;
            lbImg.alt = alt || "";
            lightbox.classList.add("open");
            document.body.style.overflow = "hidden";
        }
        function closeLightbox() {
            lightbox.classList.remove("open");
            document.body.style.overflow = "";
        }
        document.querySelectorAll("[data-lightbox]").forEach(function (el) {
            el.addEventListener("click", function () {
                var img = el.querySelector("img") || el;
                openLightbox(img.getAttribute("src"), img.getAttribute("alt"));
            });
        });
        if (lbClose) lbClose.addEventListener("click", closeLightbox);
        lightbox.addEventListener("click", function (e) {
            if (e.target === lightbox) closeLightbox();
        });
        document.addEventListener("keydown", function (e) {
            if (e.key === "Escape") closeLightbox();
        });
    }

    /* ----------------------------------------- Footer current year */
    document.querySelectorAll("[data-year]").forEach(function (el) {
        el.textContent = new Date().getFullYear();
    });
})();
