# TrainWidget Redesign — Personal Website Design System

## Overview

Redesign the TrainWidget iOS app to match the design system from davidjiang.com. The app currently uses generic iOS blue theming with a standard Form layout. The redesign applies the "Retro-Analog / Natural" aesthetic — warm cream backgrounds, forest green + burnt orange accents, editorial typography, and a custom ScrollView layout replacing the standard Form.

## Scope

Full visual overhaul of the main app settings screen, plus widget polish where possible within lock screen constraints. Also adds a new MUNI Bus agency to distinguish SF bus lines from light rail.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Color approach | Faithful translation of website palette |
| Layout | Editorial scroll (custom ScrollView, no Form) |
| Hero | Overlaid photo hero (Dolores Park image) |
| Branding | "Bay Area Transit" in hero, app name stays TrainWidget |
| Dark mode | Light default, auto dark adaptation |
| Line starring | Inline with agencies (tappable chips) |
| MUNI split | Separate MUNI Metro and MUNI Bus sections |

## Color Palette

### Light Mode (Default) — "Aged Paper"

| Token | Hex | Usage |
|-------|-----|-------|
| background | #F0EBE0 | Page background, input backgrounds |
| surface | #E4DDD0 | Cards, grouped content areas |
| text | #1E2A1E | Primary text |
| muted | #7A7568 | Secondary text, subtitles, placeholders |
| primary | #2D5F2D | Toggles, links, success states, starred chips |
| secondary | #C4441A | CTA buttons (Test Connection) |
| border | #D4CCBC | Card borders, dividers, unstarred chip borders |

### Dark Mode (Auto) — "Forest Night"

| Token | Hex | Usage |
|-------|-----|-------|
| background | #161A14 | Page background |
| surface | #222820 | Cards, grouped content areas |
| text | #E4DDD0 | Primary text |
| muted | #6B7565 | Secondary text |
| primary | #4A8F4A | Toggles, links, success states |
| secondary | #E8612A | CTA buttons |
| border | #333D30 | Card borders, dividers |

### Semantic Colors

- **Success:** primary (forest green)
- **Error:** secondary (burnt orange)
- **Warning:** #B8860B (dark goldenrod)

## Typography

iOS system fonts matching the spirit of the website's type pairing:

| Role | Font | Style |
|------|------|-------|
| Hero tagline | System serif (.design(.serif)) | Italic, ~22pt |
| Hero label | System monospace (.design(.monospaced)) | Uppercase, 11pt, letter-spaced |
| Section labels | System monospace | Uppercase, 10pt, 1.5px letter-spacing |
| Body text | System default (SF Pro) | 14pt, semibold for names |
| Subtitles | System default | 11pt, muted color |
| Chips (line names) | System monospace | 11pt, bold when starred |
| Buttons | System monospace | 12pt, semibold |
| Input fields | System default | 12pt |

## Spacing

- **Base unit:** 8px
- **Section gap:** 16px between section label and next section label
- **Card padding:** 12px
- **Card border-radius:** 8px
- **Chip border-radius:** 4px
- **Button border-radius:** 6px
- **Input border-radius:** 6px
- **Chip gap:** 6px
- **Page horizontal padding:** 18px

## Layout Structure

Replace the current `NavigationStack > Form` with `ScrollView`. No navigation title — the hero serves as the header.

### Hero Section

- **Image:** Bundled photo (Dolores Park skyline, sourced from `/Users/david/Desktop/Screenshot 2026-04-18 at 11.57.20 AM.png`)
- **Layout:** Full-width, ~220pt height, edge-to-edge
- **Image position:** `object-position: center 40%` (focus on skyline, not foreground)
- **Overlay:** Linear gradient from `rgba(30,42,30,0.1)` at top to `rgba(30,42,30,0.6)` at bottom
- **Text:** Bottom-left anchored, 18px inset
  - Line 1: "BAY AREA TRANSIT" — monospace, 11pt, uppercase, letter-spaced, warm paper color at 75% opacity
  - Line 2: "Departures at a glance" — serif italic, 22pt, warm paper color (#E4DDD0)

### Agencies Section

**Section label:** "AGENCIES" — monospace, uppercase, 10pt, muted color, 1.5px letter-spacing

**Card:** Single kraft-paper card containing all four agencies, separated by 1px borders.

Each agency row contains:
- Agency name (14pt, semibold) + subtitle (11pt, muted)
- Toggle on the right, tinted forest green

When an agency is toggled **on**, its known lines appear below as a row of tappable chips separated by a dashed border:
- **Starred chip:** Forest green background, white text, monospace, shows "★"
- **Unstarred chip:** Background-colored with border, dark text, monospace

When an agency is toggled **off**, no chips are shown.

**Agencies:**

| Agency | Subtitle | Known Lines |
|--------|----------|-------------|
| MUNI Metro | Light rail | F, J, K, L, M, N, T, S |
| MUNI Bus | SF bus lines | No hardcoded list — all non-metro MUNI lines are included automatically. No chips shown (toggle only, like AC Transit). |
| BART | Bay Area Rapid Transit | Existing known lines from current code |
| AC Transit | East Bay bus | No known lines (toggle only) |

**Data model change:** The current `TransitAgency` enum has three cases: `.muni`, `.bart`, `.acTransit`. This needs a fourth case: `.muniBus`. Both `.muni` (renamed to `.muniMetro`) and `.muniBus` use the same 511 API agency code ("SF") but filter differently:
- `.muniMetro`: Filter to lines F, J, K, L, M, N, T, S
- `.muniBus`: Include all other MUNI lines (everything not in the metro filter)

### Connection Section

**Section label:** "CONNECTION"

**Card contents:**
- "API Key" label (12pt)
- SecureField with background-colored fill, 1px border, 6px radius
- Link: "Get a free key at 511.org →" — forest green, underlined with 3px offset

### Location Section

**Section label:** "LOCATION"

**Card contents:**
- Single row: checkmark + coordinates on left, "Update" button on right
- Update button: background-colored with border, monospace text, forest green
- Error/denied states: same as current but with redesigned colors (burnt orange for errors)

### Test Connection Button

- Centered, full-width-ish (inline-block with generous padding)
- Burnt orange (#C4441A) background, white text
- Monospace font, 12pt, semibold
- 6px border radius
- Loading state: replace text with ProgressView
- Result appears below as a label with checkmark/error icon

### Setup Checklist Section

**Section label:** "SETUP"

**Card contents:**
- Three rows: API Key, Location, Agencies
- Each row: forest green checkmark (or muted circle) + label
- No toggles, read-only status indicators

### Footer Hint

- Centered text below setup: "Long-press lock screen → Customize → add TrainWidget"
- 11pt, muted color

## Widget Extension Changes

Lock screen widgets are tightly constrained by iOS (no custom colors, system-tinted rendering). Changes are limited to:

- **Font weight adjustments:** Match the monospace + weight hierarchy from the main app where it improves readability
- **Spacing refinements:** Tighten or loosen spacing to match the 8px grid
- **No color changes:** Lock screen widgets render in the system's tint color

## Dark Mode Implementation

- Define all colors in the asset catalog with light/dark appearance variants
- Reference them via `Color("tokenName")` or as `AppTheme` static properties
- Use `@Environment(\.colorScheme)` only where non-color values need to differ (e.g., overlay gradient opacity)
- The hero image overlay gradient should darken slightly more in dark mode for contrast
- All surface/border/text colors swap to their dark equivalents

## Asset Changes

- **Add:** Dolores Park hero image to `Assets.xcassets` (crop/compress appropriately for iOS)
- **Update:** App icon could optionally be refreshed to match the new palette (forest green tram on cream), but this is not required for the redesign

## Files to Modify

| File | Changes |
|------|---------|
| `TrainWidget/Theme.swift` | Replace with full color system (light/dark palettes, typography helpers) |
| `TrainWidget/ContentView.swift` | Complete rewrite — ScrollView layout, hero, inline chips, new sections |
| `Shared/Models.swift` | Add `.muniBus` case to `TransitAgency`, rename `.muni` to `.muniMetro`, update known lines |
| `Shared/TransitAPI.swift` | Update MUNI line filtering for metro vs bus split |
| `Shared/UserDefaultsStore.swift` | Handle migration of `.muni` → `.muniMetro` in stored preferences |
| `TrainWidgetExtension/DepartureWidget.swift` | Minor spacing/weight polish |
| `Assets.xcassets` | Add hero image |

## Out of Scope

- App icon redesign
- Home screen widget support (only lock screen)
- New transit agencies beyond the four listed
- Onboarding flow or first-run experience
- Animations beyond standard SwiftUI transitions
