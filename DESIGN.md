# Szlauch Design Guide

## Layout

- The default popover is one compact instrument surface: header, weather,
  transfer, system/hotspot history and local controls.
- Hairline separators and spacing establish hierarchy in the default surface;
  expanded tasks may use separate glass surfaces where density requires it.
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

- System font and monospaced digits for changing measurements.
- Compact supporting labels should remain at least 8.5 pt.
- Text and glyphs use system foreground colors; data traces use a sufficiently
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
  complete surface vertically. The popover remains a fixed 360 x 420 pt
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
- System authorization is requested only at the point of action, with plain
  language before the sleep permission dialog and a visible removal command.
