---
id: "0004"
title: "Show the local date and improve dashboard flow"
type: FEATURE
status: blocked
related_tasks: ["0002"]
related_adr: []
tags: ["design", "release"]
links: []
history:
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

After the owner resolves the agreement, submit the signed DMG again, staple
and validate it, rerun release tests with notarization required, replace the
draft asset and publish. The previous official DMG remains available.
