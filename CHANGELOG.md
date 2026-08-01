# Changelog

## 0.1.0

Initial release — a port of the React [kbar](https://github.com/timc1/kbar) package for
Flutter desktop and web.

### Added

- `KBarProvider`, `KBarPortal`, `KBarPositioner`, `KBarAnimator`, `KBarSearchField` and
  `KBarResults` — headless primitives mirroring kbar's component set.
- `KBarPalette` — a ready-to-use palette assembled from those primitives, themed through
  `KBarThemeData` (a `ThemeExtension`) and overridable row by row.
- Nested actions via `KBarAction.parent`, with descend-on-select, Backspace-to-parent, and
  ancestor breadcrumbs on flattened search results.
- Fuzzy matching with section grouping and priority ordering. `KBarFuseMatcher` (default)
  reproduces kbar's fuse.js ranking and is validated against a fixture captured from real
  fuse.js; `KBarCommandScoreMatcher` ports cmdk's `command-score` for short command names.
  Both report matched character ranges, which `KBarHighlightedText` renders.
- Global keyboard handling: a configurable toggle binding, arrow/`Ctrl+N`/`Ctrl+P` navigation
  that skips section headings, Enter, Escape, and per-action shortcuts including multi-key
  sequences.
- Opt-in undo/redo via `KBarOptions.enableHistory` and `KBarActionContext.undoWith`.
- Focus is returned to whatever held it before opening, unless something else claimed focus
  while the palette was closing — so an action that opens a dialog keeps it.
- `KBarSelector` for slice-based rebuilds, `KBarMatchesBuilder` for results, and
  `KBarRegisterActions` / `KBarActionsMixin` for scoped action registration.

### Notes

- Zero runtime dependencies beyond `collection`, which Flutter already pins. Wasm-ready.
- Differs from kbar deliberately in a few places — undo registration, live options, a
  genuinely two-way search field, and a list of toggle bindings. See the README.
