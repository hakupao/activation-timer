# Stoker Design Language — "Forge" (Tended Ember)

> Status: **LOCKED (2026-05-29) — direction approved; implementing roadmap §12.**
> Confirmed: activation = **bold ember warmth**; header = **two-step** (½-step deeper);
> tool colors = **keep Claude-purple / Codex-green**; app icon = **macOS squircle**.
> Self-decided: `StokerTheme` via EnvironmentKey; single `design-tokens.json` → Swift + CSS;
> ON-signal = ember; per-size small-icon art.
> Source: synthesized from a 6-lens design audit (see `AUDIT.md`). All color/contrast
> values are WCAG-measured, not eyeballed. Anchored to the app's name + function:
> *Stoker = one who tends a furnace fire.*

---

## 0. Personality / Tone

**Calm, warm, precise, deliberate, quietly confident.**

Stoker is the night-shift operator who tends the furnace. It speaks in terse status,
never celebration ("Schedule on. Next run 08:00." — not "Great, you're all set!"), and
its visual signature is a banked-but-lit ember that warms the entire room the moment the
schedule is active. The interface is graphite-and-ivory quiet at idle and glows
ember-warm when working — **one coherent temperature shift, never a disjointed patch of color.**

---

## 1. Concept

The whole interface behaves like a forge: **banked and quiet when idle, warm and lit when
active.** The toggle is the act of stoking. When the schedule turns ON, the entire
window — header included — rises in temperature together (cool graphite/ivory → warm
ember-tinted), and an ember status dot ignites. This single, synchronized temperature
shift is the brand's signature moment and the fix for the old "disjointed" (割裂) feeling
where only the body changed color while the dark header stayed neutral.

Voice: a calm operator on night shift. Terse, factual, status over celebration.

---

## 2. Primitive Palette (source of truth)

| Primitive | Hex | Notes |
|---|---|---|
| graphite | #171716 | core dark neutral |
| graphite_2 | #232323 | raised dark neutral |
| ink | #0E0F0D | deepest dark |
| ember | #E36E43 | brand accent (the lit core) |
| ember_hot | #FFB15E | hot highlight / glow only |
| copper | #B97A54 | warm secondary / idle accent |
| ivory | #F3EEE6 | core light neutral |
| ash | #D6D0C7 | light secondary neutral |
| sage | #9EB392 | minor cool accent |
| sage_deep | #64755F | minor cool accent (dark surfaces) |
| mist | #EAF0E9 | faint cool tint |
| ok | #43B86C | success (dark surfaces only as-is) |
| warn | #D89D38 | warning (dark surfaces only as-is) |
| danger | #DC5B54 | danger (dark surfaces only as-is) |
| **accent-deep** (NEW) | **#B5482A** | ember darkened — ember text/icons on LIGHT (4.63:1 on ivory) |
| **ok-light** (NEW) | **#2E8F50** | success on light surfaces (3.58:1) |
| **warn-light** (NEW) | **#A8741E** | warning on light surfaces (3.57:1) |
| **danger-light** (NEW) | **#C0392F** | danger on light surfaces (4.78:1) |

> **Conflict-resolution rule:** where lenses disagreed on hex, the **contrast-VERIFIED**
> values from the color/theming lens win. Raw brand `ok/warn/danger` FAIL 3:1 on the cream
> surfaces (measured 2.6–2.7:1), so light surfaces use the darkened `*-light` variants;
> dark surfaces keep the brand hex (all pass 5.5–9:1).

---

## 3. Semantic Tokens — LIGHT theme

| Semantic token | Hex | Usage |
|---|---|---|
| surface | #F4F0E9 | window base fill (idle) |
| surface-active | #FBEFE3 | window base fill (schedule ON — ember-warmed cream) |
| header | #ECE6DC | top header band (idle) — one half-step deeper than surface |
| header-active | #F6E2CE | top header band (ON) |
| card | #FBF8F2 | card fill (idle), translucent over surface |
| card-active | #FFF6EC | card fill (ON) |
| hairline | #DED7CD | dividers, card strokes (replaces hard Divider()) |
| fill-subtle | rgba(23,23,22,0.06) | pill/track backgrounds |
| on-surface (text-primary) | #1A1916 | primary text (15.48:1) |
| text-secondary | #55514A | secondary text (6.94:1) |
| text-muted | #827C72 | muted/caption (3.64:1) |
| accent | #B97A54 (copper) | idle chrome accents (calendar icon, time pills) |
| accent-on | #D85A2C | ON-signal: toggle tint + status dot (3.42:1 on active header track) |
| accent-text | #B5482A | ember-as-text/icon on light surfaces (4.63:1) |
| positive (ok) | #2E8F50 | success states (3.58:1) |
| warning (warn) | #A8741E | warning states (3.57:1) |
| danger | #C0392F | error states (4.78:1) |
| accent-sage | #5E7257 | minor cool accent, secondary only (4.60:1) |
| series-claude | #7B5FCB | Claude data series (4.26:1) |
| series-codex | #1A8F58 | Codex data series (3.62:1) |

## 4. Semantic Tokens — DARK theme

| Semantic token | Hex | Usage |
|---|---|---|
| surface | #1B1B1A | window base fill (idle) |
| surface-active | #2B211A | window base fill (ON — warm ember-brown; dR+16 vs idle = clearly-visible warmth, tuned bolder per user) |
| header | #232322 | top header band (idle) |
| header-active | #382819 | top header band (ON — tuned bolder) |
| card | #242423 | card fill (idle) |
| card-active | #33271E | card fill (ON — tuned bolder) |
| hairline | rgba(243,238,230,0.12) | dividers, strokes |
| fill-subtle | rgba(243,238,230,0.08) | pill/track backgrounds |
| on-surface (text-primary) | #F1ECE3 | primary text (14.65:1) |
| text-secondary | #B8B1A6 | secondary text (8.11:1) |
| text-muted | #9D968B | muted/caption (≥4.83:1 on all dark surfaces incl. warmer active; lightened from #8A8479 to keep AA after bolder warmth) |
| accent | #B97A54 (copper) | idle chrome accents |
| accent-on | #FF8A4D | ON-signal: toggle tint + status dot (7.12:1 on active surface) |
| accent-text | #E36E43 | ember-as-text on dark (5.62:1) — fine as both fill and text here |
| accent-hot | #FFB15E | glow / hot-core highlight only, never body text |
| positive (ok) | #43B86C | success (~7:1) |
| warning (warn) | #D89D38 | warning (~7.5:1) |
| danger | #DC5B54 | error (~4.8:1) |
| accent-sage | #9EB392 | minor cool accent (7.65:1) |
| series-claude | #8F70D9 | Claude data series |
| series-codex | #2EBF7D | Codex data series |

---

## 5. SYNCHRONIZED Toggle-Activation Model (the core requirement)

State = a **theme**, not a single tint color. Resolved across two axes:
appearance (light/dark) × state (idle/active) = **4 fully-specified surface states**. The
header, body cards, footer, AND window base all read from the same idle/active token pair
and animate off ONE `value: isOn` so the whole window changes temperature in lockstep. No
region is left neutral.

Two-step surface model: header sits one half-step deeper than the surface (same hue
family) for gentle hierarchy, but header-vs-surface contrast stays **1.09–1.11:1 in all 4
states** (verified < 1.3:1 = reads as one unified band, not "fenced"). The idle→active read
is carried by **warmth shift**, not a hard edge.

| Region | LIGHT-IDLE | LIGHT-ACTIVE | DARK-IDLE | DARK-ACTIVE |
|---|---|---|---|---|
| Window base / surface | #F4F0E9 | #FBEFE3 | #1B1B1A | #2B211A |
| **Top header band** | **#ECE6DC** | **#F6E2CE** | **#232322** | **#382819** |
| Card fill | #FBF8F2 | #FFF6EC | #242423 | #33271E |
| Hairline | #DED7CD | #DED7CD | rgba(243,238,230,.12) | rgba(243,238,230,.12) |
| Primary text | #1A1916 | #1A1916 | #F1ECE3 | #F1ECE3 |
| ON status dot + toggle tint | (off: muted) | #D85A2C | (off: muted) | #FF8A4D |
| App-icon badge ember core | dim copper | ignited ember | dim copper | ignited ember |

**Implementation mechanics that kill the disjointment:**
1. Remove the two hard `Divider()`s (MainView.swift:45, :57); replace with `hairline`
   token strokes where separation is genuinely needed.
2. Give the header an **explicit** `header`/`header-active` background so its shift is
   intentional, not incidental (today UnifiedHeader has no fill of its own, so the tint
   only showed in gutters).
3. Change cards from opaque `controlBackgroundColor` to translucent `card`/`card-active`
   (≈0.7 alpha or material) so warmth bleeds through cards instead of being masked.
4. Drive every surface from one `isOn` with one shared transition.

---

## 6. Typography Scale

| Role | Size / Weight / Family |
|---|---|
| display | 20 / Semibold / SF Pro Display (rounded) |
| title | 16 / Semibold / SF Pro Display |
| body | 13 / Regular / SF Pro Text |
| label | 11 / Medium / SF Pro Text |
| caption | 10 / Regular / SF Pro Text |
| mono | 11 / Regular / SF Mono (logs, schedule times, JSON) |

Web fallback stack (canonical font token):
`"SF Pro Display", -apple-system, BlinkMacSystemFont, "Inter", system-ui, sans-serif`.

## 7. Spacing / Radius / Elevation

- Spacing: 4 / 8 / 12 / 16 / 24 (xs/sm/md/lg/xl).
- Radius: sm 8, md 12 (= existing DS.cardRadius), lg 18 (web cards), pill = capsule.
- App-icon corner radius ratio ≈ 0.213 × side (218/1024, matches squircle convention).
- Elevation-1: black 12% alpha, blur 8, y-offset 3 (one shared shadow token; remove baked
  shadow on AppIconBadge).

## 8. Motion Principle — "the forge igniting"

One coordinated motion, not a background fade with controls snapping. Single transition
constant `forgeTransition = .easeInOut(duration: 0.45)` applied with `value: isOn` to:
window base, header fill, card fills, hairlines, accent tints, and the icon-badge ember
glow — all simultaneously. The ember status dot **ignites** on activate: scale 0.85→1.0 +
ember glow (shadow ember 0.6, radius 4) over ~0.3s, then settles **static** (no perpetual
pulse — Stoker is calm, not attention-seeking). Press feedback unchanged (scale 0.95, 0.1s).

## 9. Iconography Rules

- Brand motif: **ember core + aperture shell + schedule arc** ("no literal flame"; use
  ember/aperture/time-arc/quota-bead).
- Line icons: 64-unit viewBox, stroke 4 (≈6.25% of canvas), monochrome on-surface stroke,
  exactly **one ember accent dot** per glyph.
- Menu bar: a **single black-on-alpha template image** (#000000, ~18pt / 36px @2x),
  `isTemplate = true`; do NOT encode ON/OFF via color (system tints templates uniformly) —
  express state via symbol variant or the window, not the menu-bar tint. Delete the
  redundant white variant.
- App icon: ONE furnace/aperture mark in ember+graphite+sage; same mark drives `.icns`,
  the in-app AppIconBadge, and (mono) the menu bar. Retire the blue/teal/gold clock-bolt
  entirely. No baked drop shadow on icons.

## 10. Portability to a future Web UI

All color, type, spacing, radius, and motion values live as **semantic tokens**
(surface, surface-active, header, on-surface, accent, accent-on, positive, warning, danger,
series-claude, series-codex, hairline…) decoupled from primitives. A single
`design-tokens.json` (primitive layer + semantic-role layer) generates BOTH a Swift
`StokerTheme`/DS extension AND CSS `:root` custom properties from one Python step alongside
`tools/generate_stoker_assets.py`. The web UI consumes the exact same role names, so the
forge identity and the idle→active temperature shift port 1:1 (CSS `[data-state="active"]`
swapping the same surface/header tokens, `prefers-color-scheme` for light/dark).

---

## 11. App-Icon Plan

- **Keep the large AI concept** (aperture + copper tick ring + sage progress arc + ember
  core) as the brand mark. Hand-author a clean **vector SVG** from the existing 23-line
  `stoker-app-icon-source.svg` skeleton — reshape the 4-point star path into a 6-blade
  aperture; target ember-to-body luminance ~3.7×.
- **Author DISTINCT simplified artwork for the small iconset slots** (Apple `.iconset`
  supports per-size art — do not single-downscale):
  - **16px**: rounded body + ember disc (≥22% width) + one sage arc stub. NO ring/ticks/bead.
  - **16@2x & 32px**: + a single thin ring.
  - **32@2x (64px)**: + the 6-blade aperture, still no ticks.
  - **128px+**: full detail, NO quota bead.
- Ship on a **transparent** square canvas (squircle radius ≈229px); fix the icon generator
  to clear transparent instead of filling an opaque square.
- **Wire it into the build** so the design-pack icon stops being orphaned (today the app
  ships a generic blue/teal/gold icon instead).

---

## 12. Implementation Roadmap

| Step | What | Key files |
|---|---|---|
| **1. Lock + produce the app icon + small variant** | Adopt the AI-concept aperture mark; hand-author vector SVG; author per-size simplified iconset slots; transparent squircle; wire into build. | `design/stoker-ui-pack/assets/logo/stoker-app-icon-source.svg`; `tools/generate_stoker_assets.py`; `app/StokerMenuBar/build-app.sh` (CFBundleIconFile); the in-app `AppIconBadge` |
| **2. One design-tokens.json → appearance+state-aware Swift DS** | Add 4 contrast-safe primitives + semantic-role layer; introduce `StokerTheme` resolved by (colorScheme × isOn) = 4 variants; remap activeGreen / accentBlue / accentOrange / claudePurple / codexGreen / quotaColor; delete dead `DS.activeBg`. | `design/stoker-ui-pack/design-tokens.json` (new); `StokerMenuBarApp.swift` DS enum (253-296) + `AppIconBadge` (637-663); `ActivityView.swift` series/status colors |
| **3. Replace windowActiveTint with synchronized whole-window theme** | Remove `windowActiveTint` + its consumer; drive container from surface/surface-active; give `UnifiedHeader` an explicit header/header-active fill; make cards translucent; remove the 2 hard Dividers; one `forgeTransition` on `value: isOn`; ON dot/toggle = ember. | `MainView.swift` (bg 61-64, Dividers 45/57, header 95-184, status dot/toggle 121-130); `StokerMenuBarApp.swift` (windowActiveTint 262-267, cardBg 282) |
| **4. Menu-bar template + remaining surfaces + verify** | Replace SF "timer" menu-bar label with the black-on-alpha brand template (isTemplate); delete white variant; convert remaining raw `Color.primary.opacity` surfaces to tokens; build + visually verify all 4 states + 16/32px legibility. | `StokerMenuBarApp.swift` (MenuBarExtra label 22, raw-opacity sites); `MainView.swift` (153,212); `preview/styles.css` `:root` |

---

## 13. Open Decisions (need user sign-off before build)

1. **State color semantics** — confirm active/ON = **WARM EMBER** (light #D85A2C / dark #FF8A4D), retiring the generic green wash. *(Recommended: yes, ember.)*
2. **Activation intensity** — A subtle ("banked but lit", faint wash) vs **B bold** (clearly ember-warm whole window). User called the old one disjointed, not too strong → leaning B. Confirm.
3. **Header treatment** — two-step (header ½-step deeper, contrast 1.09–1.11:1) vs fully seamless single fill. *(Recommended: two-step.)*
4. **Tool series colors** — keep Claude=purple / Codex=green as vendor identity (light #7B5FCB / #1A8F58, dark #8F70D9 / #2EBF7D) vs re-skin to copper/sage. *(Recommended: keep purple/green.)*
5. **Icon shape language** — free-form furnace mark vs canonical macOS squircle (radius ≈229px); and confirm authoring DISTINCT per-size 16/32px art (required — both candidates go muddy below ~48px).
6. **Theme delivery mechanism** — inject `StokerTheme` via SwiftUI EnvironmentKey (cleaner, web-portable) vs extend the static DS enum with per-slot NSColor(name:) tokens (smaller diff). *(Recommended: EnvironmentKey.)*
7. **Source-of-truth format** — confirm a single `design-tokens.json` (primitives + semantic roles) that generates BOTH Swift DS and CSS `:root` is the intended web-portability mechanism.
