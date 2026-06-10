# Privacy

Szlauch is a local macOS menu bar application. It has no user account and does
not operate a server that collects usage data.

## Data stored on this Mac

Szlauch stores settings and measurement history in macOS user defaults,
including the selected display unit, palette settings, weather source,
remembered weather location, selected WireGuard service identifier, local
network history, including daily hotspot download and upload measurements.

## Network requests

Weather and place search use external forecast services:

- Open-Meteo for geocoding and forecasts.
- MET Norway for forecasts when that source is selected.

Requests include the coordinates or city necessary to obtain a forecast.
Szlauch does not send transfer history, VPN configuration, CPU/RAM
measurements, or hotspot usage values to these services.

## macOS permissions and local controls

- Location is used for local weather and, where required by macOS, displaying
  nearby Wi-Fi network names.
- WireGuard control uses the existing WireGuard VPN services registered in
  macOS. Szlauch remembers the selected service identifier locally.
- The optional `Nie usypiaj` control asks macOS once for administrator
  authorization. If approved, Szlauch installs a limited sudoers rule that
  permits only toggling `pmset -a disablesleep 0` and
  `pmset -a disablesleep 1` without asking again. Szlauch never sees or
  stores the administrator password. The menu beside this switch can remove
  the rule later; macOS requests administrator authorization for that removal.

## Removing local state

Removing the application does not automatically remove stored preferences.
The `Wyczyść` action in hotspot history removes recorded hotspot values while
leaving whole-Mac transfer history intact.
On first launch after the quota feature was retired, Szlauch removes any old
stored mobile-limit and billing-cycle values.
Before removing the app, use `Usuń zgodę macOS` in the menu beside
`Nie usypiaj` to remove the optional system sleep rule.
