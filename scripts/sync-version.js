#!/usr/bin/env node
/**
 * sync-version.js
 *
 * Single source of truth: srv/frontend/package.json "version"
 * Propagates appVersion to all Helm Chart.yaml files.
 */
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'srv', 'frontend', 'package.json'), 'utf-8'));
const version = pkg.version;

const charts = [
    'helm/Chart.yaml',
    'srv/frontend/helm/Chart.yaml',
    'srv/backend/helm/Chart.yaml',
    'srv/wordd/helm/Chart.yaml',
];

let updated = 0;
for (const rel of charts) {
    const file = path.join(root, rel);
    if (!fs.existsSync(file)) {
        console.warn(`  SKIP  ${rel} (not found)`);
        continue;
    }
    const original = fs.readFileSync(file, 'utf-8');
    const replaced = original.replace(/^appVersion:\s*".*"$/m, `appVersion: "${version}"`);
    if (replaced !== original) {
        fs.writeFileSync(file, replaced);
        console.log(`  SYNC  ${rel} → ${version}`);
        updated++;
    } else {
        console.log(`  OK    ${rel} (already ${version})`);
    }
}

console.log(`\n✔ version ${version} — ${updated} file(s) updated`);
