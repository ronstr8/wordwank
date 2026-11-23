import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';
import { BRAND } from './brand';

// Locales come in two layers, both served from /locales/:
//   <lang>.json          shared base wording (the Logodal voice)
//   <brand>.<lang>.json  optional brand overlay: only keys that brand words
//                        differently (e.g. wordwank.en.json)
// The overlay is deep-merged over the base, so a brand only ships what differs
// and every other string stays in sync automatically.

// Cache-buster for locale fetches: changes with every frontend build, not just releases.
const version = `${__APP_VERSION__}-${__GIT_SHA__}`;

async function fetchJson(url, { optional = false } = {}) {
    const res = await fetch(url);
    const type = res.headers.get('content-type') || '';
    // SPA fallbacks answer unknown paths with index.html; treat that as missing.
    if (!res.ok || !type.includes('json')) {
        if (optional) return {};
        throw new Error(`Failed to load ${url}: ${res.status}`);
    }
    return res.json();
}

function deepMerge(base, over) {
    const out = { ...base };
    for (const [k, v] of Object.entries(over || {})) {
        out[k] = v && typeof v === 'object' && !Array.isArray(v) && base[k] && typeof base[k] === 'object'
            ? deepMerge(base[k], v)
            : v;
    }
    return out;
}

const BrandedBackend = {
    type: 'backend',
    init() {},
    read(lng, _ns, callback) {
        const base = fetchJson(`/locales/${lng}.json?v=${version}`);
        const overlay = BRAND === 'logodal'
            ? Promise.resolve({})
            : fetchJson(`/locales/${BRAND}.${lng}.json?v=${version}`, { optional: true });
        Promise.all([base, overlay])
            .then(([b, o]) => callback(null, deepMerge(b, o)))
            .catch((err) => callback(err, null));
    },
};

i18n
    .use(BrandedBackend)
    .use(LanguageDetector)
    .use(initReactI18next)
    .init({
        fallbackLng: 'en',
        load: 'languageOnly', // en-US -> en; we ship no regional files
        interpolation: {
            escapeValue: false
        }
    });

export default i18n;
