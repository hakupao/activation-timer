# Stoker Design Audit — Evidence Log

> 6-lens multi-agent audit of `design/stoker-ui-pack` + the live SwiftUI app.
> 7 agents, ~471k tokens, 112 tool calls, ~6 min. All values tool-measured.
> Feeds `THEME.md`. Retained as evidence per workflow discipline.

## Scores (current state, 0–10)

| Lens | Score | One-line verdict |
|---|---|---|
| macOS HIG conformance | 3.5 | App ships 3 inconsistent, off-brand icons; none follow Stoker identity |
| Synchronized theming + WCAG | 4.0 | "Disjoint" is architectural; delivered a verified 4-state token map |
| App-icon quality / small-size | 5.5 | Whole iconset is one downscale of the muddy PIL master; AI concept not wired in |
| Asset production-readiness | 6.5 | Pack is clean & fully reproducible; the problem is wiring, not file integrity |
| Brand tone / portable tokens | 4.5 | Strong ownable idea, but shipping app uses none of it; no semantic-token layer |
| SwiftUI gap analysis | 4.0 | Code is well-structured for a theme overhaul, but identity is generic blue/green/purple |

## Cross-cutting critical findings (verified)

1. **The app's whole Stoker ember brand is unwired.** The shipping `.icns` AND the in-app
   `AppIconBadge` (StokerMenuBarApp.swift:637–663) are a blue(0.10,0.31,0.70)→teal(0.03,0.62,0.58)→gold(0.95,0.67,0.22)
   gradient with SF `timer` + `bolt.fill`. The design pack's icons (PIL + AI concept) are
   orphaned — zero references from `app/`. *(Verified directly: AppIconBadge source read.)*
2. **The "disjointment" (割裂) root cause** is NOT a stray header background. The tint at
   `MainView.swift:61–64` is on the OUTER VStack, so the header *does* inherit it — but
   (a) opaque cards (`DS.cardBg = .controlBackgroundColor`, StokerMenuBarApp.swift:282)
   paint OVER the tint so only the header strip + inter-card gutters change color;
   (b) two hard `Divider()`s (MainView.swift:45,57) fence the header off; (c) in dark mode
   the active tint srgb(0.09,0.15,0.11) barely differs from the window background.
3. **Window is NOT force-dark.** Only appearance reference is the `windowActiveTint`
   `NSColor(name:)` closure (StokerMenuBarApp.swift:263) that resolves light/dark from the
   system. The app follows system appearance → the user sees the *light-mode* active tint
   rgb(0.90,0.96,0.92) = pale mint. *(Verified: no `preferredColorScheme`/appearance forcing
   anywhere.) → adding a light+dark theme is NOT a structural rewrite.*
4. **Contrast math forced palette additions.** Raw brand `ok/warn/danger` fail 3:1 on cream
   (2.6–2.7:1); ember fails on ivory (2.76:1). Hence new primitives accent-deep #B5482A,
   ok-light #2E8F50, warn-light #A8741E, danger-light #C0392F for light surfaces.

## Token remap (live DS → forge theme), with call sites

- `DS.activeBg` (StokerMenuBarApp.swift:258) — **DEAD CODE, zero call sites → delete.**
- `DS.activeGreen` → **SPLIT**: `ok` #43B86C for success (StokerMenuBarApp.swift:564,620; ActivityView.swift:163,251); `accent-on` ember for ON-identity (MainView.swift:121,123,130).
- `DS.accentBlue` (9 sites: StokerMenuBarApp.swift:509,563,679,722,741,743,787; MainView.swift:295; ActivityView.swift:162) → `accent` copper/ember. *Single biggest "generic macOS blue → Stoker" shift.*
- `DS.accentOrange` → **SPLIT**: `warn` (StokerMenuBarApp.swift:565; ActivityView.swift:164,252); `accent`/copper for decorative icons (StokerMenuBarApp.swift:464,895).
- `DS.claudePurple` / `DS.codexGreen` → `series-claude` / `series-codex` (StokerMenuBarApp.swift:902,908; MainView.swift:164,169; ActivityView.swift:84,92,103,111,258). *Note: codexGreen rgb(0.18,0.75,0.49) near-duplicates activeGreen — must diverge.*
- `DS.cardBg` opaque `.controlBackgroundColor` (StokerMenuBarApp.swift:282) → translucent `card`/`card-active` so warmth bleeds through.
- `windowActiveTint` (StokerMenuBarApp.swift:262–267) + consumer (MainView.swift:61–64) → `surface`/`surface-active`.

## Icon specifics

- Whole `.iconset` is byte-identical downscale of the PIL master (md5 6bf7f3b4…). 16px →
  illegible blob + faint dot.
- AI concept `stoker-imagegen-app-icon-concept.png`: 1254px, **hasAlpha: no**, opaque
  near-black corners → not iconset-ready without resample-to-1024 + alpha + squircle, and
  needs a hand-authored SVG (no vector source exists).
- `Stoker.icns` in the pack IS valid (748505 bytes, 10 types, full 16→1024 iconset) — but
  it's the muddy PIL art and isn't what ships.

## Lower-severity / follow-ups

- Menu-bar pack ships redundant black AND white template PNGs (template needs black+alpha
  only); glyph is ~3–4px off-center in its 96px canvas; 96px is an odd master (author at 18/36px).
- Generator hardcodes `/System/Library/Fonts/.../Arial*.ttf` (silent fallback on CI) and
  `ImageFont.load_default()` in the empty-state scene — affects only non-shipping preview art.
- PNGs ship untagged (no ICC profile) — harmless for UI, optionally tag marketing PNGs sRGB.
