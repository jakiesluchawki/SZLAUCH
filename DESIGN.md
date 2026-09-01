# Szlauch Design Guide

## Layout

- The default popover is one compact instrument surface: header, weather,
  transfer, system/hotspot history and local controls.
- Hairline separators and spacing establish hierarchy in the default surface;
  details share the same outer glass surface, without a stack of outlined cards.
- Main navigation actions (`WIĘCEJ`, `SIECI`, `7 DNI`, `WRÓĆ`) are inline
  labels with chevrons, not capsule buttons.
- Expansion replaces supporting content in the same panel; the return action
  is always labelled `WRÓĆ`.
- Detail screens retain an analytical handoff: process details keep an inline
  live-transfer shortcut to `WYKRES`, and transfer details keep an inline
  CPU/RAM shortcut to `PROCESY`.
- In analytical, Wi-Fi and hotspot-history detail screens, tapping passive
  surface returns to the dashboard; explicit actions keep their own
  destinations. Weather is exempt so forecast exploration and the Weather
  app shortcut are never treated as dismiss gestures.
- The expanded Wi-Fi view keeps a single compact `HOTSPOT OSOBISTY` shortcut
  above nearby networks; configuring a phone is a one-time inline edit, not a
  settings page.
- The current SSID is a selected state, not a connection action. Selecting it
  never asks for a password; the Wi-Fi glyph is the compact shortcut to the
  native macOS Wi-Fi settings pane.

## Information Language

- `TRANSFER · CAŁY MAC` identifies rates aggregated over physical external
  interfaces such as Wi-Fi or Ethernet.
- `VPN lokalny` is reserved for a WireGuard service controlled on this Mac.
  A router-side tunnel may affect transfer but is not a local toggle.
- `Nie usypiaj` describes the active prevention action, rather than suggesting
  that sleep itself is enabled.
- `HOTSPOT · DZIŚ` reports measured metered traffic without implying a plan
  limit; its inline history shows downloaded and uploaded values by day.
- `HOTSPOT OSOBISTY` is a saved connection shortcut, distinct from measured
  hotspot traffic and honest about whether the phone is currently available.
- Transfer readouts retain one spatial order in every view: download first,
  upload second.

## Type And Contrast

- Bundle the licensed Roobert Regular/Bold for UI and measurements; reserve
  Romie Regular for the wordmark and short detail headings. Keep tabular digits.
- Font binaries are ignored local build inputs, not public source assets.
  System sans/serif fallback is intentional for source builds without fonts.
- Compact supporting labels remain at least 9.5 pt; technical monospaced axis
  labels may use 9 pt. Main readouts separate a large value from its quiet unit.
- The instrument panel always uses its authored dark appearance, even when
  macOS is in Light Mode; system appearance must never turn labels black on
  the dark Zgrywa palettes.
- Text uses warm off-white ink and muted supporting colors; weather glyphs retain
  a contrasting native foreground. Data traces use a sufficiently
  visible stroke even while the panel tint is personalised.
- Window opacity has a readability floor of 62 percent.

## Color

- The user cycles three authored palettes; never generate random combinations:
  `Śliwka` (`#17141C`, `#241D2C`, `#B59AF7`) is the default instrument mood,
  `Mech` (`#111915`, `#17231D`, `#33E982`) is natural, `Zatoka`
  (`#0E171A`, `#14252A`, `#41D2C2`) is cool.
- `strong`, `action` and metric fills derive from each palette accent.
- Transfer preserves semantic temperature: download is a cool cyan/teal trace
  and upload is a warm apricot trace in every palette.
- Warning and failure states use stable high-contrast warm colors so that
  personalisation does not blur meaning.

## Motion And Control

- View transitions use a calm 220 ms eased dissolve without shifting the
  complete surface vertically. The popover remains a fixed 384 x 472 pt
  surface in every state, so opening details cannot move its frame or arrow.
- Selection changes inside a detail view use a shorter 160 ms ease-out
  response rather than reading as navigation.
- Weather remains on the dashboard and in its own forecast state; analytical
  details omit the repeated weather summary to fit the fixed instrument frame.
- Weather detail uses its spare vertical room for one calm `WARUNKI` section:
  apparent temperature appears only when meaningfully different, while
  wind/gusts, precipitation and air quality receive semantic color only when
  noteworthy. Forecast providers live in one compact source menu.
- Long analytical content scrolls inside the fixed middle area while the
  header remains stationary.
- Utility actions live in a small gear menu after the refresh cadence; they
  never compete with measurements at the bottom of the panel.
- Clicking `Szlauch` rotates the palette; horizontal dragging changes color
  intensity and vertical dragging changes panel opacity.
- A new installation and the first launch after the contrast migration start
  at 100 percent window opacity. Later user adjustments remain persistent.
- System authorization is requested only at the point of action, with plain
  language before the sleep permission dialog and a visible removal command.

## Detail Density

- Transfer gives the linear chart 132 pt, five Y levels and stable units.
  Sparklines stay below values and never cross the typography.
- System uses a full-width ranking with Processor/Memory tabs, explicit entry
  from each dashboard metric, eight processes and thin per-core meters.
- Hotspot has a dedicated seven-day table, without repeated Wi-Fi/CPU cards.
  Reset starts a separate hotspot display baseline, never deletes whole-Mac data.
- Unknown rainfall/AQI stays unknown. Stale forecasts are identified, and
  rain intervals retain each provider's preceding/next-hour semantics.
- Readouts update without rolling-number animations. Reduce Motion disables
  navigation animation; Reduce Transparency uses an opaque panel surface.
- Errors are dismissible overlays and cannot change the panel's route or size.

## Visual Verification

`--snapshot <directory>` renders fixture-based layouts without polling, saving
measurements or changing connections. The portable renderer uses an opaque
surface and state icons/text for AppKit controls it cannot rasterize.
These are layout/type previews, not a substitute for testing native glass,
menus, toggles, scrolling and popover positioning in the application.
