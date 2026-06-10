# Contributing

Szlauch is a native macOS menu bar application written in Swift and SwiftUI.

## Development setup

Requirements:

- macOS 13 or newer
- Xcode command-line tools
- Python 3 only when building the DMG

Build the application:

```bash
./scripts/build-macos-app.sh
open -na "Szlauch.app"
```

Run the complete local release checks:

```bash
./scripts/build-dmg.sh
./scripts/test-release.sh
```

## Pull requests

- Keep changes focused.
- Preserve the fixed 360 x 420 pt panel unless a change explicitly revisits
  that product constraint.
- Add or update a self-test for behavior changes.
- Do not commit generated applications, DMGs, signing material, local
  preferences, screenshots containing private data, or credentials.
- Update `README.md`, `DESIGN.md`, or `PRIVACY.md` when behavior, design
  language, or data handling changes.

## Security

Before committing, run:

```bash
gitleaks dir . --config .gitleaks.toml --redact
```

Report security issues using the process described in `SECURITY.md`.
