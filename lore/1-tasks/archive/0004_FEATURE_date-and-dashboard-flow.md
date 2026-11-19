---
id: "0004"
title: "Show the local date and improve dashboard flow"
type: FEATURE
status: completed
related_tasks: ["0002"]
related_adr: []
tags: ["design", "release"]
links: []
history:
  - date: "2026-11-19"
    status: completed
    who: mieszko
    note: "Apple accepted the submission. Published the stapled DMG and verified the running installation over SSH on the owner's MacBook Pro M2."
  - date: "2026-11-19"
    status: blocked
    who: mieszko
    note: "0.5.0 built and signed. Apple refused notarization submission with HTTP 403 because an agreement requires action by the account holder."
  - date: "2026-11-19"
    status: active
    who: mieszko
    note: "Review the panel and prepare version 0.5.0."
---

# Local date and dashboard flow

Show today's local date alongside weather and group related network measurements.

Reviewed all eight rendered screens before and after the change. The weather
header now shows the local Polish weekday and date even while loading. Forecast
and conditions precede location controls. Hotspot totals follow network rates.
Native preview checks exercised the forecast and hotspot round trips.

The second design pass gives the calendar and weather separate columns,
uses the display face for the date, and condenses daily hotspot totals into
one line. The transfer readouts use Polish labels and lightly tinted plots.

All 14 suites passed in the optimized universal app and from the mounted DMG.
The native background bookmark resolved inside the remounted image. Both code
signatures verify. Intel runtime and live VPN/sleep changes were not exercised.

Apple accepted submission `d3aee745-809f-4aa8-b1b6-bfb8b8b4fc2f`. All
release checks passed with notarization required. The public GitHub Latest
asset matched the stapled image's SHA-256, `3cd00bb4577fd178ac50291580ce4b10803a9c143daf5cb3fb1439133a1d15d8`.
The laptop already had the matching signed executable. Attached and validated
its ticket in place. Gatekeeper accepted it and the application kept running.
