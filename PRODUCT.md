# Szlauch Product Guide

## Product

Szlauch is a macOS menu bar utility for people who need trustworthy working
context without giving away menu bar space. It combines whole-Mac network
rate, metered-data awareness, weather, CPU/RAM, local WireGuard control and a
sleep blocker in one compact panel.

## Users

- A Mac user working on the move, especially over phone tethering who wants to understand daily use.
- Teammates installing a DMG without sharing one hard-coded VPN profile.
- People who want one glanceable status surface instead of several permanent widgets.

## Personality

- Native and calm: it should feel at home on macOS, with restrained glass and clear hierarchy.
- Zgrywa-branded, not corporate gray: color can be playful, but it must never hide values.
- Honest: labels must state whether a control is local and whether a measurement is whole-device.

## Anti-References

- Dense dashboard cards nested inside more dashboard cards.
- Decorative low-contrast graphs or icons that make data difficult to read.
- UI that implies a router VPN can be toggled locally, or that Wi-Fi alone equals all traffic.
- Technical errors exposed as permanent status messages after a cancelled system dialog.

## Product Principles

1. Values first: current rates and today's hotspot download are readable at a glance.
2. Measurement scope is visible: whole-Mac transfer and local-only VPN control are labelled.
3. Detail is progressive: weather, network history, Wi-Fi selection and system processes expand in place.
4. Personalisation is safe: palettes and transparency never lower basic legibility.
5. Privileged actions are reversible: explain the one-time sleep permission and let the user remove it.
6. Frequent tethering is direct: a saved phone hotspot is reachable from Wi-Fi
   detail without pretending the app can expose Apple-only Continuity lists.
7. Detail is easy to leave: passive surface returns to status, but explicit
   destinations and forecast exploration remain intentional actions.

## Trust And Privacy

Measurements and preferences remain local. Weather queries send only the
place needed for a forecast. Preview windows are read-only and only one normal
Szlauch instance is allowed to collect transfer data at a time.
