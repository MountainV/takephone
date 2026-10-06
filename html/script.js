const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'takeperso';

const menu = document.getElementById('menu');
const menuItems = document.getElementById('menu-items');
const menuSubtitle = document.getElementById('menu-subtitle');
const menuCounter = document.getElementById('menu-counter');
const menuDesc = document.getElementById('menu-desc');
const cardWrapper = document.getElementById('card-wrapper');
const card = document.getElementById('card');

let docs = [];
let cardTimer = null;

// Menüzustand: null = Hauptmenü, sonst ausgewähltes Dokument
let currentDoc = null;
let entries = [];
let selected = 0;

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function esc(value) {
    return String(value ?? '-').replace(/[&<>"']/g, c => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    })[c]);
}

/* ---------------- Menü ---------------- */

function buildEntries() {
    if (!currentDoc) {
        menuSubtitle.textContent = 'DOKUMENTE';
        entries = docs.map(doc => ({
            label: doc.label,
            right: '›',
            desc: `Nr. ${doc.number}`,
            action: () => { currentDoc = doc; selected = 0; renderMenu(); }
        }));
        if (entries.length === 0) {
            entries.push({ label: 'Keine Dokumente vorhanden', desc: '', action: () => {} });
        }
        return;
    }

    const doc = currentDoc;
    menuSubtitle.textContent = doc.label.toUpperCase();
    entries = [
        { label: 'Ansehen', desc: 'Dokument selbst ansehen.', action: () => post('view', { id: doc.id }) },
        { label: 'Zeigen', desc: 'Dem nächsten Spieler vorzeigen.', action: () => post('show', { id: doc.id }) }
    ];
    if (doc.canGive) {
        entries.push({ label: 'Geben', desc: 'Dem nächsten Spieler übergeben.', action: () => post('give', { id: doc.id }) });
    }
    entries.push({ label: 'Zurück', desc: '', action: back });
}

function renderMenu() {
    buildEntries();
    if (selected >= entries.length) selected = entries.length - 1;

    menuItems.innerHTML = '';
    entries.forEach((entry, i) => {
        const row = document.createElement('div');
        row.className = 'menu-item' + (i === selected ? ' selected' : '');
        row.innerHTML = `<span>${esc(entry.label)}</span><span class="right">${entry.right ? esc(entry.right) : ''}</span>`;
        row.onmouseenter = () => { selected = i; updateSelection(); };
        row.onclick = () => entry.action();
        menuItems.appendChild(row);
    });
    updateSelection();
}

function updateSelection() {
    [...menuItems.children].forEach((row, i) => row.classList.toggle('selected', i === selected));
    menuCounter.textContent = `${selected + 1}/${entries.length}`;
    menuDesc.textContent = entries[selected]?.desc || '';
}

function back() {
    if (currentDoc) {
        const idx = docs.indexOf(currentDoc);
        currentDoc = null;
        selected = Math.max(idx, 0);
        renderMenu();
    } else {
        post('close');
    }
}

/* ---------------- Karten ---------------- */

// ?t=... verhindert, dass ein altes, zwischengespeichertes Foto angezeigt wird
let photoVersion = 0;
function photo(headshot) {
    return headshot ? `<img src="https://nui-img/${headshot}/${headshot}?t=${Date.now()}_${photoVersion}">` : '';
}

function signature(h) {
    return `<span class="signature">${esc(h.firstname)} ${esc(h.lastname)}</span>`;
}

function field(label, value) {
    return `<div><span class="lbl">${label}</span><span class="val">${esc(value)}</span></div>`;
}

const templates = {
    id: (doc, h, img) => `
        <div class="head">
            <div>
                <div class="country">${esc(doc.country)}</div>
                <div class="doctype"><b>PERSONALAUSWEIS</b> &nbsp;IDENTIFICATION CARD</div>
            </div>
            <div class="docno">${esc(doc.number)}</div>
        </div>
        <div class="photo">${photo(img)}</div>
        <div class="fields">
            ${field('Name / Surname', h.lastname)}
            ${field('Vornamen / Given names', h.firstname)}
            <div class="row">
                ${field('Geburtstag / Date of birth', h.dob)}
            </div>
            <div class="row">
                ${field('Staatsangehörigkeit / Nationality', h.nationality)}
                ${field('Gültig bis / Date of expiry', doc.expires)}
            </div>
            ${field('Geburtsort / Place of birth', h.birthplace)}
        </div>
        <div class="ghost">${photo(img)}</div>
        <div class="sign-wrap"><span class="lbl">Unterschrift / Signature</span>${signature(h)}</div>
        <div class="access">${esc(doc.accessNumber)}</div>
    `,

    driver: (doc, h, img) => {
        return `
            <div class="badge"><span class="star">★</span><span class="cc">${esc(doc.countryCode)}</span></div>
            <div class="title">
                <div class="big">FÜHRERSCHEIN</div>
                <div class="small">${esc(doc.country)}</div>
            </div>
            <div class="photo">${photo(img)}</div>
            <div class="fields">
                <div class="f"><span class="n">1.</span><span class="v">${esc(h.lastname)}</span></div>
                <div class="f"><span class="n">2.</span><span class="v">${esc(h.firstname)}</span></div>
                <div class="f"><span class="n">3.</span><span class="v">${esc(h.dob)} ${esc(h.birthplace)}</span></div>
                <div class="f"><span class="n">4a.</span><span class="v">${esc(doc.issued)}</span><span class="n">4b.</span><span class="v">${esc(doc.expires)}</span></div>
                <div class="f"><span class="n">4c.</span><span class="v">${esc(doc.authority)}</span></div>
                <div class="f"><span class="n">5.</span><span class="v">${esc(doc.number)}</span></div>
                <div class="f"><span class="n">9.</span><span class="v">${esc(doc.classes)}</span></div>
            </div>
            <div class="sign-wrap"><span class="lbl" style="font-size:11px;font-weight:700">7.</span>${signature(h)}</div>
        `;
    },

    weapon: (doc, h, img) => `
        <div class="head">
            <div>
                <div class="big">WAFFENBESITZKARTE</div>
                <div class="small">${esc(doc.country)}</div>
            </div>
            <div class="docno">Nr. ${esc(doc.number)}</div>
        </div>
        <div class="photo">${photo(img)}</div>
        <div class="fields">
            ${field('Name', h.lastname)}
            ${field('Vorname', h.firstname)}
            <div class="row">
                ${field('Geburtsdatum', h.dob)}
                ${field('Geburtsort', h.birthplace)}
            </div>
            <div class="row">
                ${field('Ausgestellt am', doc.issued)}
                ${field('Gültig bis', doc.expires)}
            </div>
            ${field('Erlaubnis für', doc.classes)}
        </div>
        <div class="stamp">${esc(doc.authority)}<br>WAFFEN&shy;BEHÖRDE</div>
        <div class="sign-wrap"><span class="lbl">Unterschrift des Inhabers</span>${signature(h)}</div>
    `
};

function showCard(doc, headshot, duration) {
    clearTimeout(cardTimer);
    photoVersion++;

    const tpl = templates[doc.template] || templates.id;
    card.className = `card tpl-${templates[doc.template] ? doc.template : 'id'}`;
    card.innerHTML = tpl(doc, doc.holder || {}, headshot);

    cardWrapper.classList.remove('hidden');

    if (duration) cardTimer = setTimeout(hideCard, duration);
}

function hideCard() {
    clearTimeout(cardTimer);
    cardWrapper.classList.add('hidden');
}

function setBanner(banner) {
    if (!banner) return;
    const el = document.getElementById('menu-banner');
    el.textContent = banner.text ?? '';
    el.style.backgroundColor = banner.color || '';
    el.style.backgroundImage = banner.image ? `url("${banner.image}")` : '';
}

/* ---------------- Events ---------------- */

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'openMenu':
            docs = data.docs || [];
            setBanner(data.banner);
            currentDoc = null;
            selected = 0;
            renderMenu();
            menu.classList.remove('hidden');
            break;
        case 'closeMenu':
            menu.classList.add('hidden');
            break;
        case 'showCard':
            showCard(data.doc, data.headshot, data.duration);
            break;
        case 'hideCard':
            hideCard();
            break;
    }
});

document.addEventListener('keydown', e => {
    if (menu.classList.contains('hidden')) return;

    switch (e.key) {
        case 'ArrowUp':
            selected = (selected - 1 + entries.length) % entries.length;
            updateSelection();
            break;
        case 'ArrowDown':
            selected = (selected + 1) % entries.length;
            updateSelection();
            break;
        case 'Enter':
            entries[selected]?.action();
            break;
        case 'Escape':
            post('close');
            break;
        case 'Backspace':
            back();
            break;
    }
});
