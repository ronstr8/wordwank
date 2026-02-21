---
description: maintenance tasks (syncing i18n, updating changelog, bumping version)
---

# 🛠️ Maintenance Checklist

Use this checklist when finalizing a batch of features or preparing for a release.

## 1. 🌐 Sync Localization (i18n)

- [ ] **Frontend**: Ensure `en.json`, `es.json`, and `fr.json` in `srv/frontend/src/locales/` have identical keys.
  - Check for interpolation syntax: Use `{{variable}}` for frontend i18next.
- [ ] **Backend**: Update the `translations` helper in `srv/backend/lib/Wordwank.pm`.
  - Check for interpolation syntax: Use `{variable}` for manual regex replacement or `%s` for `sprintf`.

## 2. 📝 Update Changelog

- [ ] Add a new version header to `CHANGELOG.md` (e.g., `## [0.24.0] - YYYY-MM-DD`).
- [ ] Categorize changes under `### Added`, `### Fixed`, or `### Changed`.
- [ ] Ensure any [BREAKING] changes are clearly marked.

## 3. 🏷️ Versioning (SemVer)

- [ ] Bump the version in `srv/frontend/package.json` (single source of truth).
// turbo
- [ ] Run `node scripts/sync-version.js` to propagate to all Helm charts.
- [ ] Ensure the version in `CHANGELOG.md` matches.

## 4. 🧹 Cleanup

- [ ] Remove any temporary debug logs or `console.log` statements.
- [ ] Verify that all new features include the appropriate `t()` translation calls.

## 5. 🚀 Commit

- [ ] Suggest a concise commit message of 70 characters or fewer that summarizes the maintenance work.
