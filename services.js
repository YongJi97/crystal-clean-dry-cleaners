/* Fill the home "From" prices and the pricing panels from /data/services.json.
   The HTML already on the page is the no-JS fallback and stays put if the
   fetch fails. Updates rewrite text inside the existing cards so scroll-reveal
   state is unchanged. */
(function () {
    function money(amount) {
        var n = Number(amount);
        if (!isFinite(n)) return "";
        return "$" + n.toFixed(2);
    }

    function setNote(el, text) {
        var icon = el.querySelector("i");
        el.textContent = "";
        if (!icon) {
            icon = document.createElement("i");
            icon.className = "fas fa-circle-info";
            icon.setAttribute("aria-hidden", "true");
        }
        el.appendChild(icon);
        el.appendChild(document.createTextNode(" " + text));
    }

    function row(item) {
        var li = document.createElement("li");
        var name = document.createElement("span");
        name.className = "name";
        name.textContent = item.name;
        var dots = document.createElement("span");
        dots.className = "dots";
        var amt = document.createElement("span");
        amt.className = "amt";
        amt.textContent = money(item.price);
        li.appendChild(name);
        li.appendChild(dots);
        li.appendChild(amt);
        return li;
    }

    function renderFeature(panel, category) {
        var item = (category.items && category.items[0]) || {};
        var price = item.price != null ? item.price : (category.from && category.from.price);
        var big = panel.querySelector(".big");
        if (big && price != null) {
            big.textContent = "";
            big.appendChild(document.createTextNode(money(price)));
            var unit = item.unit || (category.from && category.from.unit);
            if (unit === "lb") {
                var small = document.createElement("small");
                small.textContent = " / lb";
                big.appendChild(small);
            }
        }
        var noteText = item.notes || category.notes;
        var note = panel.querySelector(".price-note");
        if (note && noteText) setNote(note, noteText);
    }

    function renderList(panel, category) {
        var ul = panel.querySelector(".price-rows");
        if (ul && category.items && category.items.length) {
            ul.textContent = "";
            category.items.forEach(function (item) {
                ul.appendChild(row(item));
            });
        }
        var note = panel.querySelector(".price-note");
        if (note && category.notes) setNote(note, category.notes);
    }

    function renderCategory(category) {
        var nodes = document.querySelectorAll('[data-service="' + category.id + '"]');
        Array.prototype.forEach.call(nodes, function (panel) {
            if (panel.classList.contains("service-card")) {
                var fromEl = panel.querySelector(".from");
                var priceEl = panel.querySelector(".price");
                if (fromEl && category.from && category.from.label) fromEl.textContent = category.from.label;
                if (priceEl && category.from && category.from.price != null) {
                    priceEl.textContent = money(category.from.price);
                }
                return;
            }
            if (category.layout === "feature" || panel.classList.contains("price-highlight")) {
                renderFeature(panel, category);
                return;
            }
            renderList(panel, category);
        });
    }

    fetch("/data/services.json", { headers: { Accept: "application/json" } })
        .then(function (response) {
            if (!response.ok) throw new Error("services.json " + response.status);
            return response.json();
        })
        .then(function (data) {
            (data.categories || []).forEach(renderCategory);
        })
        .catch(function () {
            /* Keep the hardcoded HTML. */
        });
})();
