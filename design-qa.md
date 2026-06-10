# Design QA: Szlauch 0.3.12

## Reference

Approved Product Design direction: hybrid of the expressive `Plama` palette
and the ordered `Instrument` layout, with inline navigation rather than
capsule backgrounds under `WIĘCEJ`, `SIECI`, `7 DNI` and `WRÓĆ`.

The original concept image and interaction recording were local design inputs
and are intentionally not included in the public repository.

Full-view comparison evidence:
`/tmp/szlauch-0.3.1-design-comparison.png` (approved concept at left, native
default dashboard at right).

Scoped Wi-Fi extension evidence:
`/tmp/szlauch-0.3.2-wifi-hotspot.png` (native expanded Wi-Fi state with the
personal hotspot shortcut).

Navigation correction evidence:
`/tmp/szlauch-0.3.3-traffic-navigation.png` and
`/tmp/szlauch-0.3.3-system-navigation.png` (native transfer and process
detail states after the interaction repair).

Motion refinement evidence:
`/tmp/szlauch-0.3.4-traffic-motion.png`,
`/tmp/szlauch-0.3.4-system-motion.png` and
`/tmp/szlauch-0.3.4-popover-traffic.png` (final detail states and the
menu-bar-anchored popover before the motion comfort correction).

Motion comfort correction evidence:
`/tmp/szlauch-0.3.5-popover-traffic.png` and
`/tmp/szlauch-0.3.5-popover-system.png` (menu-bar-anchored detail states
after removing vertical surface travel and slowing the transition rhythm).

Fixed-frame correction evidence:
runtime checks across dashboard, traffic, process, Wi-Fi, hotspot and weather
states report the same fixed 360 x 420 pt application frame; no state observer
can modify the popover content size after it opens.

Weather detail evidence:
`/tmp/szlauch-audit-crops/weather-polish.png` (native expanded weather state
with one calm conditions section, compact source menu and semantic emphasis
inside the fixed panel).

## Verified States

- Default dashboard: one continuous glass surface, readable weather, primary
  download and secondary upload with traces, compact system/hotspot/control
  rows and no navigation capsules.
- Transfer details: scale, range and fixed-unit picker remain visible; an
  inline `SYSTEM · CPU · RAM · PROCESY` row restores direct access to process
  analysis without returning to the dashboard. The top readouts now preserve
  dashboard order: `DOWNLOAD` first, `UPLOAD` second.
  Implementation screenshot: `/tmp/szlauch-0.3.3-traffic-navigation.png`.
- Process details: cores and top CPU/RAM applications remain visible; an
  inline live `TRANSFER · WYKRES` row restores current download/upload and
  navigation to its chart.
  Implementation screenshot: `/tmp/szlauch-0.3.3-system-navigation.png`.
- Hotspot history: seven daily rows remain usable and return action uses the
  new inline treatment.
- Wi-Fi selection: the added `HOTSPOT OSOBISTY` row keeps a saved phone and a
  single direct `POŁĄCZ` action above ordinary networks; its one-time `ZMIEŃ`
  edit follows the existing inline navigation language without growing the
  default dashboard.
- Theme: `Śliwka` is the new-install default; the existing `Mech` and `Zatoka`
  palette choices remain available.

## Findings And Patches

- Resolved P1: mutually exclusive analytical detail screens removed useful
  context. Process details now expose live transfer plus `WYKRES`; transfer
  details now expose CPU/RAM plus `PROCESY`.
- Resolved P1: compact CPU/RAM and transfer affordances were too easy to miss.
  Their buttons now own their full rectangular visual areas.
- Resolved P1: switching to a repeatedly used phone hotspot required leaving
  Szlauch for System Settings. A compact saved-phone shortcut now invokes a
  known macOS Wi-Fi connection first and falls back to targeted hidden-network
  scanning plus the existing password request.
- Resolved P1: an already active secured SSID could still be treated as a new
  connection action and fall through to a misleading password request.
  Canonically equivalent SSID names now share one selected identity, the
  active row is non-actionable, periodic Wi-Fi refresh clears stale password
  prompts, and switching networks first asks macOS to use its saved
  credentials.
- Resolved P2: the Wi-Fi glyph communicated status but offered no native
  escape hatch. It now opens the macOS Wi-Fi settings pane directly from both
  dashboard and expanded network states.
- Resolved P1: Light Mode could make semantic system text black while the
  authored Szlauch surface remained dark. The panel now owns a consistent
  dark appearance and explicit light foreground tokens. Version 0.3.12 also
  performs a one-time reset to 100 percent window opacity; later user changes
  remain persistent.
- Resolved P1: entering transfer detail swapped the spatial order of download
  and upload beneath the cursor. Detail now matches the dashboard.
- Resolved P2: returning from process/transfer/Wi-Fi/hotspot detail relied on
  locating `WRÓĆ`. Passive detail surface now returns to the dashboard while
  named actions retain their destinations; weather remains deliberately
  exempt.
- Resolved P2: view changes felt heavy because content and popover sizing
  changed without one motion rhythm. The initial 120 ms treatment was too
  abrupt in daily use; navigation now uses a calm 220 ms opacity dissolve
  without surface travel, and in-view selection uses 160 ms.
- Resolved P1: switching to the most useful details still resized the
  menu-bar popover, creating a visibly rough frame jump. All views now use
  one fixed 360 x 420 pt frame; weather is kept on the dashboard and forecast
  view, but is not redundantly shown above analytical detail content.
- Resolved P1: the shortest fixed-frame attempt clipped long traffic and
  hotspot content. Detail content now scrolls within a stationary center
  region.
- Resolved P1: footer actions visually overlapped the scrollable transfer
  summary and made analytical screens feel crowded. `Start przy logowaniu`
  and `Zakończ Szlauch` now live in a compact gear menu beside the refresh
  cadence; detail content receives the full remaining fixed-frame height.
- Resolved P2: traffic details repeated two sparklines directly above the
  primary chart. The live readouts remain, but the redundant mini charts are
  removed from the analytical state.
- Resolved P3: the launch-at-login menu item repeated its state in copy.
  It now uses a native menu toggle with the neutral `Start przy logowaniu`
  label, so the checkmark alone communicates state.
- Resolved P2: the fixed-height process detail view left a large quiet area
  below a very compact system summary. It now uses that space for eight readable
  CPU and RAM applications per column plus a slightly taller core skyline.
- Resolved P2: the expanded weather view gave four equally prominent tiles to
  values that were not equally useful. It now uses one quieter `WARUNKI`
  section, omits apparent temperature when it matches the actual temperature,
  avoids repeating precipitation copy and applies semantic color only to
  notable rain, wind or air-quality values.
- Resolved P3: three adjacent weather-provider buttons competed with forecast
  exploration. They now live in one compact native source menu with a visible
  current selection.

## Fidelity Review

- Typography: system type, monospaced numeric values and hierarchy remain
  aligned with the approved instrument layout.
- Spacing: the two new shortcut rows use hairline-separated compact sections,
  preserving the panel rhythm rather than adding cards or capsules.
- Color: shortcuts reuse the Śliwka accent and semantic teal/apricot transfer
  colors; no new competing token was introduced.
- Assets: weather and system glyph treatment remains unchanged; this patch
  introduces no replacement imagery.
- Weather hierarchy: hourly forecast remains visually primary; `WARUNKI` reads
  as supporting context, and the provider control no longer resembles a
  primary action.
- Copy: `WYKRES` and `PROCESY` name the destination directly and are more
  explicit than an ambiguous expansion label.
- Interaction: the passive-return gesture adds no competing visual control;
  the existing inline `WRÓĆ` remains available and discoverable.
- Motion: the refined transition is restrained and calm; it dissolves
  surfaces without vertically moving the entire panel or animating data
  traces as page navigation.
- Frame stability: navigation no longer changes popover content size, so its
  position and menu-bar arrow remain fixed while the content changes.
- Wi-Fi copy: `HOTSPOT OSOBISTY`, `POŁĄCZ` and `ZMIEŃ` state the intent
  directly; no faux Instant Hotspot list is promised where public macOS API
  does not expose one.
- The concept mock is deliberately taller and more illustrative than the
  production popover. The released panel preserves its compact menu-bar
  footprint, an established product constraint, while retaining the concept's
  hierarchy and palette.

## Validation

- Reviewed the supplied recording and rendered native preview windows for the
  two repaired analytical states.
- Rendered and reviewed the expanded Wi-Fi state with a configured phone
  shortcut; it remains within the existing detail-panel
  footprint with readable hierarchy and no new capsule navigation.
- Verified the Wi-Fi settings URL against macOS 26.5.1 and added a focused
  SSID-identity self-test covering active, canonically equivalent, distinct
  and missing network names.
- Rendered transfer and system details after the correction; transfer order is
  consistent and the existing analytical controls remain visible.
- Rendered the final transfer and process states after motion refinement, and
  the then-resizing popover transfer state; this established the visual
  baseline before the fixed-frame correction.
- Verified the fixed-frame correction structurally and by runtime window-size
  checks across dashboard, transfer, system, Wi-Fi, hotspot and weather
  states; all retain the same dimensions and analytical views no longer repeat
  the dashboard weather summary.
- Rendered the simplified transfer state after moving utility actions into the
  header gear menu; the footer no longer overlaps measurements and the
  redundant analytical sparklines are gone.
- Rendered the refined weather detail state after consolidating practical
  conditions and forecast-source controls; it remains within the same fixed
  frame and leaves a calmer visual hierarchy.
- A synthetic range click against the native preview was attempted but macOS
  did not deliver it without Accessibility permission; visible state rendering
  is verified, and a navigation self-test validates passive dismissal while
  preserving the weather exception.
- App release tests cover VPN, sleep, fixed rate units, aggregate network
  measurement, Wi-Fi selection, hotspot history, personal hotspot preference,
  detail navigation, read-only preview mode and themes.
- Manually verified the 0.3.12 migration by starting from a stored 62 percent
  opacity value: the panel opened at 100 percent and recorded the migration,
  matching the intended first-run behavior.

final result: passed
