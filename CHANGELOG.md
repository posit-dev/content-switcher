# Changelog

All notable changes to the content-switcher extension are documented in this file.

This project uses [Semantic Versioning](https://semver.org/).

## 0.1.1

### Fixed

- Deep links to a heading inside a non-default variant now work. On load, the
  extension selects the variant that owns the anchor target and then scrolls to
  it. A plain link such as `page.html#set-up-user-provisioning` now lands on the
  correct section, even when that section belongs to a variant that is not the
  default. ([#35](https://github.com/posit-dev/content-switcher/issues/35))

### Added

- Clicking an in-page anchor that points into a different variant switches to
  that variant automatically and scrolls to the target.
- Changing the selector writes the choice to the URL as a `?version=` parameter,
  so the address bar is always a shareable link.

### Notes

- The initial variant is now chosen in this order (highest first): the variant
  that owns the anchor in the URL, the `?version=` URL parameter, the last
  selection saved in `localStorage`, then the selector default.

## 0.1.0

Initial release.

- Block-level and inline content switching with the `content-switcher` class.
- Dropdown selector with configurable position and label.
- `?version=` URL parameter for a direct link to a variant.
- Selection saved in `localStorage` across visits.
- Auto-detection of variants from content.
- `content-switcher:changed` custom event for extensibility.
- Selector position options, including placement after a named section.
- Dark mode support.
