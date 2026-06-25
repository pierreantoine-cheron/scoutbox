# ScoutBox Design System

> Source of truth: `frontend/lib/utils/` (app_colors.dart, design_constants.dart, app_theme.dart)
> Visual reference: `design/v1/scoutbox.html`

---

## Brand identity

ScoutBox is a gear-inventory tool for scouts (scoutisme francophone). The brand voice is **utilitarian, calm, and trustworthy** — a clean Material 3 toolkit with a single green accent that signals readiness and nature, paired with neutral greys that stay out of the way.

- Name: **ScoutBox**
- Logo: `assets/brand/logo.svg` (also `logo_1024.png` for launchers)
- Localization: French (`fr_FR`)
- Theme mode: Light only (no dark mode at this stage)

---

## Color tokens

### Core palette

| Token | Hex | OKLch equivalent | Role |
|---|---|---|---|
| `scoutGreen` (primary) | `#186A23` | `oklch(46% 0.13 145)` | Primary actions, FAB, selected states, success indicator |
| `background` | `#F9FAFB` | `oklch(98.5% 0.002 240)` | Page background (`surfaceContainerLowest`) |
| `surface` | `#FFFFFF` | `oklch(100% 0 0)` | Cards, inputs, sheets, dialogs |
| `foreground` | `#11171C` | `oklch(20% 0.014 250)` | On-surface text, titles |
| `muted` | `#646A70` | `oklch(52% 0.012 250)` | Secondary text, labels, monospace captions |
| `border` | `#DEE2E5` | `oklch(91% 0.006 250)` | Card borders, dividers, input outlines |
| `accentSoft` | `#186A23` at 12% opacity | — | Selected item backgrounds, chip highlights |

### Surface container hierarchy (Material 3)

| Token | Hex | Role |
|---|---|---|
| `surfaceContainerLowest` | `#F9FAFB` | Page background |
| `surfaceContainerLow` | `#F3F4F6` | Lowest-elevation surface |
| `surfaceContainer` | `#EDEEF0` | Mid surface |
| `surfaceContainerHigh` | `#E7E8EA` | Higher-elevation surface |
| `surfaceContainerHighest` | `#E1E2E4` | Search field fill, archived tent backgrounds |

### State / semantic colors

| Token | Hex | OKLch equivalent | Usage |
|---|---|---|---|
| `statePerfect` | `#1D9330` | `oklch(58% 0.17 145)` | "Bon état" foreground |
| `statePerfectBg` | `#DBF3DB` | `oklch(94% 0.04 145)` | "Bon état" background |
| `stateUsable` | `#C68D21` | `oklch(68% 0.15 82)` | "À réparer" foreground |
| `stateUsableBg` | `#FFEBC1` | `oklch(95% 0.06 82)` | "À réparer" background |
| `stateUnusable` | `#C91519` | `oklch(52% 0.22 25)` | "Inutilisable" / error foreground |
| `stateUnusableBg` | `#FFDCD7` | `oklch(93% 0.05 25)` | "Inutilisable" / error background |
| `stateMissing` | `#6A57B3` | `oklch(52% 0.14 290)` | "Manquant" foreground |
| `stateMissingBg` | `#ECE2FF` | `oklch(93% 0.04 300)` | "Manquant" background |

### Tag palette (10 predefined + custom)

| Label | Hex | OKLch equivalent |
|---|---|---|
| Rouge | `#DF202E` | `oklch(58% 0.22 25)` |
| Orange | `#DD7234` | `oklch(66% 0.18 62)` |
| Jaune | `#C6A136` | `oklch(72% 0.17 95)` |
| Vert | `#1D9330` | `oklch(58% 0.17 145)` |
| Bleu _(default)_ | `#1A70E5` | `oklch(56% 0.20 255)` |
| Violet | `#6A34AB` | `oklch(46% 0.18 300)` |
| Rose | `#C91B86` | `oklch(56% 0.22 350)` |
| Turquoise | `#43857F` | `oklch(54% 0.13 190)` |
| Gris | `#6D7277` | `oklch(55% 0.01 250)` |
| Marron | `#6D411C` | `oklch(42% 0.08 58)` |

Tags also support a custom hex color via `flutter_colorpicker`.

---

## Typography

### Font families

| Role | Stack |
|---|---|
| Display / Body | System default (Roboto on Android, SF Pro on iOS/macOS, Segoe UI on Windows) |
| Monospace | Platform system monospace (`'monospace'` family) |

No custom font assets are loaded — the design relies on the native platform system font for body/display and the platform monospace for data/metadata.

### Type scale (TextTheme)

| Token | Size | Weight | Letter-spacing | Usage |
|---|---|---|---|---|
| `titleLarge` | 22px | w600 | -0.33 | Page title, sheet header |
| `titleMedium` | 17px | w600 | -0.17 | Card titles, item names |
| `titleSmall` | 14px | w600 | — | Section headers inline |
| `bodyLarge` | 15px | w400 | — | Body text (rare) |
| `bodyMedium` | 14px | w400 | — | Setting descriptions, form labels |
| `bodySmall` | 12px | w400 | — | Metadata, secondary lines |
| `labelLarge` | 13px | w500 | — | Buttons, tab labels |
| `labelMedium` | 12px | w500 | — | Compact chip text |
| `labelSmall` | 11px | w500 | 0.66 | Uppercase section headers, pill badges |

### Contextual type rules

| Context | Size | Weight | Family | Color |
|---|---|---|---|---|
| Card title | 17px | w600 | default | `foreground` |
| Item name (list/detail) | 17px | w600 | default | `foreground` |
| Metadata / secondary line | 12px | w400 | default | `muted` |
| Sheet title | 20px | w600 | default | `foreground` |
| Sheet form label | 13px | w500 | default | `foreground` |
| Section header (uppercase) | 11px | w500 | mono | `muted`, `letter-spacing: 0.5` |
| Count badges ("3 modèles") | 12px | w400 | mono | `muted` |
| Character counter | 12px | w400 | mono | `muted` |
| Invite code display | 16px | w400 | mono | default, `letter-spacing: 2` |
| Desktop tab label | 13px | w600 (sel) / w500 | default | `foreground` / `muted` |
| Drawer item label | 14px | w600 (sel) / w400 | default | `foreground` / `muted` |
| ScoutPill label (full) | 14px | w500 | default | foreground color |
| ScoutPill label (compact) | 11px | w600 | default | foreground color |
| Button text | 14px | w600 | default | — |
| Empty state title | 20px | w600 | default | `foreground` |
| Empty state subtitle | 14px | w400 | default | `muted` |

---

## Spacing

### Tokens (`AppSpacing`)

| Token | Value | Usage |
|---|---|---|
| `xs` | 6px | Tight internal gaps, gap between state pill and text |
| `sm` | 10px | Card margins, inter-card gap, row item spacing |
| `md` | 16px | Screen padding (mobile), drawer padding, filter bar |
| `lg` | 24px | Screen padding (desktop), sheet horizontal padding, FAB offset |
| `xl` | 36px | Large section gaps, settings section spacing |

### Layout patterns

| Context | Padding |
|---|---|
| Screen content (mobile) | `EdgeInsets.symmetric(horizontal: 16, vertical: 14)` |
| Screen content (desktop) | `EdgeInsets.all(lg)` (24px) |
| Tent card outer margin | `EdgeInsets.symmetric(horizontal: 16, vertical: 5)` |
| Tent card inner padding | `EdgeInsets.fromLTRB(18, 16, 18, 16)` |
| Responsive item card padding | `EdgeInsets.symmetric(horizontal: 18, vertical: 14)` |
| Sheet header | `EdgeInsets.fromLTRB(24, 12, 24, 0)` |
| Sheet body | `EdgeInsets.symmetric(horizontal: 24)` |
| Input content padding | `EdgeInsets.symmetric(horizontal: 14, vertical: 10)` |
| Search field padding | `EdgeInsets.symmetric(vertical: 10, horizontal: 12)` |
| Desktop create button | `EdgeInsets.symmetric(horizontal: 14, vertical: 7)` |
| Section gap (vertical) | `SizedBox(height: 10)` or `SizedBox(height: 24)` |
| Responsive grid wrap spacing | 10px horizontal + vertical |

---

## Border radius

### Tokens (`AppRadii`)

| Token | Value | Usage |
|---|---|---|
| `sm` | 6px | Invite code container, skeleton lines, desktop tab hover |
| `md` | 10px | Buttons (filled, elevated, outlined), text inputs, popup menus, color swatches |
| `lg` | 14px | FAB, alert dialogs |
| `xl` | 18px | Cards (tent, model, tag, part, responsive list), data table wrapper |
| `pill` | 999px | Chips (ScoutPill), tag chips, state badges, sheet handle, nav indicator underline |

### Global defaults

- `CardTheme`: `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl))` (18px)
- `ChipTheme`: `shape: StadiumBorder()` (pill)
- `InputDecorationTheme`: `borderRadius: BorderRadius.circular(AppRadii.md)` (10px)
- `FilledButton` / `ElevatedButton` / `OutlinedButton` theme: `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md))` (10px)
- `FloatingActionButtonTheme`: `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg))` (14px)
- `DialogTheme`: `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg))` (14px)

---

## Elevation

### Tokens (`AppElevation`)

| Token | Value | Context |
|---|---|---|
| `none` | 0 | Cards, app bar (unscrolled) |
| `scrolled` | 1 | App bar when scrolled under |
| `fab` | 6 | FAB shadow |
| `modal` | 8 | Dialogs, bottom sheets |

### Philosophy

The design is intentionally **low-elevation, border-driven**. Cards have no elevation (`elevation: 0`) and rely on a 1px `outlineVariant` border for separation. Elevation is reserved for floating elements (FAB, dialogs, sheets) and the subtle scrolled-under app bar shadow.

---

## Components

### Card (tent)

```
┌──────────────────────────────────────────────┐
│ [state pill]  Title (17px w600)        [chev] │
│               ○ Model  ·  👤 Capacité         │
│               [tag] [tag] [+2]                │
└──────────────────────────────────────────────┘
```
- `surface` background, 1px `border` border, `AppRadii.xl` (18px)
- Hover: border shifts to `accentSoft`, subtle shadow (`0 2px 10px rgba(0,0,0,0.04)`)
- Inner layout: horizontal row — `stateCompact` pill → info (name + meta + tags) → chevron_right (20px, muted)
- Archived tents: `surfaceContainerHighest` background
- Meta line: model icon (13px) + name, people icon (13px) + size, muted, 12px

### Card (responsive item list — models, parts, tags)

```
┌──────────────────────────────────────────────┐
│ [icon]  Title (17px w600)            [···]    │
│         Meta (12px mono, muted)              │
└──────────────────────────────────────────────┘
```
- Same radius/border as tent card (`xl`, 18px)
- `PopupMenuButton` at trailing edge (edit + delete)
- Model card: 44px accent icon square (radius 10px)
- Tag card: 40px color dot (circle), with chip preview
- Part card: 36px accent icon square (radius 10px)

### Buttons

| Variant | Shape | Min size | Text | Padding |
|---|---|---|---|---|
| FilledButton | radius 10px | 0×48 | 14px w600 | h:18 v:14 |
| ElevatedButton | radius 10px | inf×48 | 15px w600 | h:18 v:10 |
| OutlinedButton | radius 10px | — | — | — |
| Desktop create | radius 10px | — | 13px w600 | 14×7 |
| Sheet footer outline | radius 10px | 0×48 | 14px w600 | — |
| Sheet footer filled | radius 10px | 0×48 | 14px w600 | h:18 v:14 |

- Fill color: `scoutGreen` (primary)
- Outline color: `border`
- Hover on filled: darken
- Hover on outline: border → `foreground`
- Disabled: 45% opacity

### Floating Action Button

- 56×56px, radius 14px, `scoutGreen` background, white icon (24px)
- Elevation: 6px
- Shadow: `0 4px 18px rgba(0,0,0,0.13)`
- Hover: darken + stronger shadow, active: `scale(0.96)`
- Hidden on desktop (≥768px), replaced by inline create button in AppBar

### Input fields

- Filled style, `surface` white background
- Radius: 10px (`AppRadii.md`)
- Border: enabled = `border` (1px), focused = `scoutGreen`, error = `stateUnusable`
- Content padding: horizontal 14px, vertical 10px
- Hint: `muted` color
- Character counter: monospace 12px, `muted`, format `$current / $maxLength`

### Search field

- Radius: 10px
- Prefix: search icon (18px, muted)
- Suffix: close icon (16px, muted) — visible only when text is present
- Optional filled mode: `surfaceContainerHighest` background
- Focus: border → `scoutGreen`, outer glow `accentSoft`

### Chip / Pill (`ScoutPill`)

Six constructor variants:

| Variant | Background | Text | Padding | Size | Context |
|---|---|---|---|---|---|
| `tag()` | Tag color (solid) | white | 8×14 | 13px w500 | Full tag display |
| `tagCompact()` | Tag color (solid) | white | 10×4 | 11px w600 | Card tag row |
| `tagFilter()` | Tag color at 15% alpha | full color | 8×14 | 13px w500 | Filter bar |
| `state()` | Semantic bg | semantic fg + icon | 8×14 | 14px w500 | Detail screen |
| `stateCompact()` | Semantic bg | semantic fg + icon | 4×10 | 11px w600 | Card leading badge |
| `filterState()` | Semantic bg | semantic fg + border | 8×14 | — | Filter bar |
| `neutral()` | Transparent | `foreground` + border | — | — | Generic |

All pills have `BorderRadius.circular(999)` (pill). All tags use `chip-tag` style (solid color background, white text).

### State badge (`StateBadge`)

Full-width state indicator used in detail screens:
- Icon: 18px
- Text: `bodyMedium` w600
- Padding: horizontal 12, vertical 8
- Radius: pill (999px)
- Four variants: perfect (green), usable (amber), unusable (red), missing (violet)

### Sheet (`SheetScaffold`)

Bottom sheet pattern used for all create/edit flows:
```
┌─────────────────────────────────────┐
│         ━━━━━━━ (handle, 36×4px)   │  ← mobile only
│  Titre (20px w600)           [✕]   │
│ ─────────────────────────────────── │
│                                     │
│  [form content, scrollable]         │
│                                     │
│ ─────────────────────────────────── │
│           [Annuler]  [Enregistrer]  │
└─────────────────────────────────────┘
```

- Handle: mobile only, hidden ≥768px
- Header: `EdgeInsets.fromLTRB(24, 12, 24, 0)`, title 20px w600
- Body: scrollable, 24px horizontal padding, 4px gap between fields
- Footer: divider + row of [OutlinedButton cancel, FilledButton save], both 48px height
- Presentation: mobile = bottom sheet (`showModalBottomSheet`), desktop = dialog (`showDialog`)

### Dialog (`showConfirmDialog`)

- `AlertDialog` with radius 14px, elevation 8px
- Title + content text
- Actions: OutlinedButton (cancel) + FilledButton (confirm)
- Destructive variant: confirm button uses `stateUnusable` red

### Empty state (`EmptyStateView`)

- Centered column
- Icon: 64px, `muted`
- Title: 20px w600, `foreground`
- Subtitle (optional): 14px w400, `muted`
- Gaps: 16px after icon, 8px after title

### Skeleton loading

- `surfaceContainerHighest` colored containers at pill radius (999px)
- Three lines: 60% width / 18px height, 35% / 14px, 45% / 14px
- Wrapped in a `Card` with margin `symmetric(horizontal: 16, vertical: 8)`

### Progress indicator

- `CircularProgressIndicator(strokeWidth: 2)`, primary color

### Data loading pattern (`DataScreenScaffold<T>`)

Generic widget that handles three states:
1. **Loading** → `AppProgressIndicator` or custom `loadingPlaceholder`
2. **Error** → `AsyncErrorView` (error icon + message + retry button)
3. **Data** → content builder callback

Wrapped in `RefreshIndicator` for pull-to-refresh.

### Filter bar

- Horizontal scrollable row of state/tag filter chips
- Layout: `Row` with `gap: 8px`, wraps to max 2 lines with overflow hidden
- Chips: `ScoutPill.tagFilter()` or `ScoutPill.filterState()`
- Optional overflow chip: "+N" in mono 12px
- Expand/collapse button: 36×36, radius 6px, border 1px, toggles chevron rotation
- Filter panel: collapsible, `background` fill, max-height transition
- Filter rows: label (mono 11px uppercase) + chip row
- Clear all link at bottom right

---

## Navigation

### Structure

5 sections defined in `NavigationSection` enum:

| Section | Label | Icon | Material Icon |
|---|---|---|---|
| `tents` | Tentes | `Icons.cabin` | cabin |
| `tags` | Étiquettes | `Icons.label_outline` | label_outline |
| `parts` | Éléments | `Icons.build_outlined` | build_outlined |
| `models` | Modèles | `Icons.grid_view_outlined` | grid_view_outlined |
| `settings` | Réglages | `Icons.settings_outlined` | settings_outlined |

### Mobile navigation (width < 768px)

- **AppBar**: hamburger menu (`Icons.menu`) leading, centered title, actions on trailing
- **Drawer**: width 300px, max 85vw, slides from left
  - Header: 36×36 SVG logo + "ScoutBox" (18px w700, display font)
  - Divider
  - 4 scrollable section items (tents, tags, parts, models): icon (18px) + label (14px) + live count badge (mono 11px, pill, accentSoft bg)
  - Divider + Settings at bottom
  - Selected: green icon/text (`scoutGreen`), `accentSoft` background, w600
  - Hover: `fgSoft` background
  - Navigates via `pushAndRemoveUntil` on inner Navigator
- **FAB**: bottom-right, 56×56

### Desktop navigation (width ≥ 768px)

- **No drawer**. No hamburger. No FAB.
- **AppBar title row**: 24×24 SVG logo + "ScoutBox" (18px w700) + top tabs
- **Top tabs**: horizontal scrollable row
  - Tab: 13px, padding 6×14, radius 6px
  - Selected: w600, `foreground`, 2.5px `scoutGreen` underline (pill radius)
  - Unselected: w500, `muted`, no underline
  - Hover: `fgSoft` background
- **AppBar actions**: search field + inline create button (13px w600, white text on `scoutGreen`, 14×7 padding, radius 10px) + action icons

### Responsive breakpoints

| Width | Behavior |
|---|---|
| `< 480px` | Archive button icon-only |
| `< 768px` | Mobile: drawer + FAB, single-column lists |
| `≥ 768px` | Desktop: top tabs, no drawer, no FAB, 2-column grid |
| `≥ 900px` | Sheet layout switches to wider dialog |
| `≥ 1100px` | 3-column grid for models/tags/parts lists |

---

## Iconography

All icons are from **Material Icons** (no custom icon font). Common sizes:

| Context | Size |
|---|---|
| Navigation (drawer) | 18px |
| AppBar actions | default (24px) |
| Card metadata | 13px |
| Card chevron | 20px |
| Empty state | 64px |
| Popup menu trigger | 18px |
| Popup menu items | 16px |
| Search prefix | 18px |
| Search clear | 16px |
| State badge | 18px |
| State badge compact | 12px |
| FAB | 24px |
| Desktop create button | 14px |
| Close button | 18px |

Icon color: `muted` by default, `scoutGreen` when selected/active, `stateUnusable` for destructive actions.

---

## Animation & interaction

| Element | Duration | Easing | Behavior |
|---|---|---|---|
| Drawer open/close | 260ms | `cubic-bezier(0.32, 0.72, 0, 1)` | Slide from left |
| Sheet open/close | 300ms | `cubic-bezier(0.32, 0.72, 0, 1)` | Slide from bottom |
| Scrim fade | 220–250ms | `ease` | Fade in/out |
| Card hover border | 140ms | — | Border color transition |
| Input focus border | 120ms | — | Border + shadow transition |
| Button hover bg | 120ms | — | Background transition |
| Chip hover | 120ms | — | Opacity 0.82 |
| FAB press | 100ms | — | `scale(0.96)` |
| Color swatch hover | 120ms | — | `scale(1.05)` |
| Fading success icon | 1600ms | — | Fade out after success action |
| Chevron on card hover | 140ms | — | `translateX(2px)` |
| Filter panel expand | 280ms | `cubic-bezier(0.32, 0.72, 0, 1)` | Max-height transition |

### Material ink ripples

All interactive surfaces (cards, list items, buttons) use `InkWell` with matching `borderRadius` for correct ripple clipping. No custom ripple colors — uses Material default.

### Scroll physics

- `BouncingScrollPhysics` (iOS-style) or platform-adaptive via `ScrollConfiguration`
- Pull-to-refresh via `RefreshIndicator`

---

## Layout principles

1. **Border over elevation.** Separation is achieved with 1px `outlineVariant` borders, not elevation shadows. Cards have `elevation: 0`. Only floating elements (FAB, sheets, dialogs) cast shadows.
2. **Single accent budget.** `scoutGreen` is the only accent color. It appears on the FAB, selected nav items, focused inputs, primary buttons, success states, and the logo. Never use it as decoration — only as affordance.
3. **Mono for data, sans for content.** All "meta" labels (counters, codes, section headers, character limits, model meta) use the system monospace font. Body text and titles use the system sans-serif.
4. **One idea per row.** Tent cards: state + name + meta + tags + chevron. No stacking of unrelated info.
5. **French locale.** All UI labels are in French. Dates are formatted with `initializeDateFormatting('fr_FR')`.
6. **No dark mode (yet).** The design system is light-only; `ThemeMode.light` is enforced.
7. **Material 3 throughout.** `useMaterial3: true`, `ColorScheme.fromSeed()` with `scoutGreen` as seed, `surfaceTint: Colors.transparent`.
8. **Surface hierarchy.** Background → surface (cards/inputs) → surfaceContainerHighest (search, archived, filled areas). Never nest more than 3 surface levels.
9. **Responsive by nature.** Mobile-first with explicit tablet/desktop adaptations. Lists switch from single-column to 2-col to 3-col at 768px and 1100px. Navigation switches from drawer+FAB to top-tabs+inline-create at 768px.

---

## File index

| File | Role |
|---|---|
| `frontend/lib/utils/app_colors.dart` | Color tokens, `AppSemanticColors`, `TagPalette` |
| `frontend/lib/utils/design_constants.dart` | `AppRadii`, `AppSpacing`, `AppElevation`, `DesignConstants` |
| `frontend/lib/utils/app_theme.dart` | `ThemeData` construction, `TextTheme`, component themes |
| `frontend/lib/utils/app_theme_context.dart` | `BuildContext` extension for semantic colors |
| `frontend/lib/providers/navigation_provider.dart` | `NavigationSection` enum |
| `frontend/lib/views/widgets/scout_pill.dart` | Pill/chip component (6 variants) |
| `frontend/lib/views/widgets/state_badge.dart` | State badge styles |
| `frontend/lib/views/widgets/sheet_scaffold.dart` | Sheet/dialog layout |
| `frontend/lib/views/widgets/sheet_footer.dart` | Cancel/save button row |
| `frontend/lib/views/widgets/tent_card.dart` | Tent card component |
| `frontend/lib/views/widgets/responsive_item_list.dart` | Grid list for models/parts/tags |
| `frontend/lib/views/widgets/search_field.dart` | Search text field |
| `frontend/lib/views/widgets/navigation_drawer.dart` | Mobile drawer |
| `frontend/lib/views/widgets/empty_state_view.dart` | Empty state placeholder |
| `frontend/lib/views/widgets/data_screen_scaffold.dart` | Loading/error/data wrapper |
| `frontend/lib/views/widgets/confirm_dialog.dart` | Confirmation + error dialogs |
| `frontend/lib/views/screens/auth_gate.dart` | Root scaffold, navigation dispatch |
| `design/v1/scoutbox.html` | Visual reference prototype |

---

## Changelog

- **2026-06-25** — Initial DESIGN.md extracted from Flutter codebase (`frontend/lib/utils/`) and `design/v1/scoutbox.html`.
