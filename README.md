# refind

A reverse marketplace for iOS: you post a **Gesuch** (a want — "I'm looking for X, up to CHF Y") and other people send **Angebote** (offers) on it. Buyer and seller negotiate in a chat attached to the offer, then confirm a handover.

SwiftUI, iOS 18.2+. Product language is German (Swiss conventions: du-form, `CHF 1'720`).

![Swift](https://img.shields.io/badge/Swift-F05138?logo=swift&logoColor=white) ![SwiftUI](https://img.shields.io/badge/SwiftUI-0D96F6?logo=swift&logoColor=white) ![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white) ![Hono](https://img.shields.io/badge/Hono-E36002?logo=hono&logoColor=white) ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)

**Repo layout:** `refind/` iOS app · `server/` API (TypeScript, Hono, Postgres) · `docs/API.md` API contract

## Status

All 18 designed screens are built and the core loop runs end to end: onboarding → post a want → receive offers → negotiate → close → mock escrow.

The app runs in two modes. **Demo mode** uses `MockRefindRepository`, an in-memory actor seeded from the design mocks, so every screen works without a server. **Live mode** uses `LiveRefindRepository` against the API in [`server/`](server/README.md), where authentication and the user profile are implemented; wants, offers, chat and deals have their database schema but no endpoints yet. Payment is simulated in both modes, and no card is ever charged.

## Architecture

```
refind/
├── App/            root, tab shell, environment, debug hatch
├── DesignSystem/   tokens + the mascot (from the design handoff)
├── Models/         Money, Want, Offer, ChatThread, Deal, Escrow
├── Repository/     RefindRepository protocol + in-memory mock + seed data
├── Screens/        one folder per screen family, each with its own store
├── Components/     shared views (cards, states, tab bar, photos)
├── Support/        formatters, load state, motion, connectivity
└── Resources/Fonts bundled TTFs
```

Screens never touch the repository directly — each goes through an `@Observable` store holding a `LoadState`, which is what keeps loading / empty / error states honest rather than optional.

`MockRefindRepository` takes `latency` and `failure` knobs, so every one of those states is reachable from a preview or a test instead of being faked per screen.

## Design system

Two fonts only: **Instrument Serif** for titles and the wordmark, **Archivo** for everything else. Cards are white with a 1 pt hairline and **square corners**; buttons are fully rounded capsules. The rust red `#B5442A` is reserved for offers, prices, live state and badges.

`DesignSystem.swift` and `FinMascot.swift` come from the design handoff and are treated as the source of truth — no colour, font name or corner radius is written anywhere else.

## Running it

Open `refind.xcodeproj`, pick an iPhone simulator, ⌘R. The design baseline is 402 × 874 (iPhone 16 Pro).

Any screen can be opened directly in debug builds:

```bash
SIMCTL_CHILD_RF_SCREEN=want-detail xcrun simctl launch <device-udid> ch.nick.refind
```

Names are in `App/DebugScreens.swift` — including `home-empty`, `home-error` and `home-loading` for the list states.

## Tests

```bash
xcodebuild -project refind.xcodeproj -scheme refind \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -parallel-testing-enabled NO test
```

Unit tests cover money and German date formatting (wrong-in-silence if it drifts) plus the repository's behaviour. UI tests drive the post-a-want flow, onboarding and the tab shell.

Parallel testing is disabled above on purpose — the test clones have been unreliable on this machine.

## Localisation

German is the source language; English is a second localisation via
`refind/Resources/Localizable.xcstrings`.

**English is incomplete.** Model display names, error copy and push copy are
translated; the ~150 literals inside views are not, so an English device shows a
mix. Finishing it is mechanical — build in Xcode, which extracts the remaining
strings into the catalog, then fill the English column. German is unaffected and
complete.

Wire values (report subject types, sort keys, enum raw values) are deliberately
outside the catalog — localising those would corrupt API requests.

## Not built yet

- **The rest of the API.** Auth and profile endpoints are done; wants, offers,
  chat, deals and escrow exist as schema only (see `server/README.md`).
- **The escrow provider**, which decides the real shape of
  `POST /escrows/{id}/authorise`.
- The chat WebSocket, so typing indicators are quiet on the live path.
- Font licence files — see `refind/Resources/Fonts/NOTICE.md` before shipping.

## Fonts

Instrument Serif and Archivo are from Google Fonts, licensed under the SIL Open Font License 1.1. See `refind/Resources/Fonts/NOTICE.md`.
