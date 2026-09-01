# Trace

Trace is groundwork for a privacy-first Matrix client built with Flutter. The
initial targets are Android, Linux, and web, with iOS planned. Product features are kept behind
domain and platform boundaries so the visual interface can be redesigned
without rewriting protocol code.

The client uses the Dart Matrix SDK with vodozemac end-to-end encryption. The
SDK is AGPL-3.0-or-later; see the architecture notes before distributing a
combined application.

The application shell is now connected to a persistent Matrix client on
Android, Linux, and web. It restores sessions, syncs real rooms and encrypted
timelines, and can exchange text and files. The mock conversations remain only
as the dependency-free widget-test fixture. See
[`docs/product/PRODUCT_BRIEF.md`](docs/product/PRODUCT_BRIEF.md) for the agreed
scope and [`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md)
for the dependency rules. Remaining alpha work and platform limitations are
tracked in [`docs/product/ALPHA_CHECKLIST.md`](docs/product/ALPHA_CHECKLIST.md).
Longer-term messaging, media, calling, accessibility, moderation, and platform
ideas are collected in the
[`future feature catalog`](docs/product/FUTURE_FEATURE_CATALOG.md).

## Development

With Nix flakes enabled:

```sh
nix develop
flutter pub get
flutter test
flutter analyze
```

Run one of the supported targets:

```sh
flutter run -d linux
flutter run -d android
flutter run -d chrome
```

Optional open-web GIF and sticker search is configured at build time. Users do
not need provider keys; distributors configure the shared Trace relay and
GIPHY app integration. See
[`docs/protocols/MEDIA_SEARCH.md`](docs/protocols/MEDIA_SEARCH.md) and the
[`relay README`](tool/media_search_relay/README.md).

Android builds run automatically for `main`, `unstable`, pull requests, and
version tags. The branch, signing, configuration, and tagging conventions are
documented in [`docs/engineering/RELEASES.md`](docs/engineering/RELEASES.md).
The reusable conventions behind this setup are summarized in the
[`Flutter app baseline`](docs/engineering/FLUTTER_APP_BASELINE.md).

### Android with Obtainium

[![Add Trace to Obtainium](https://img.shields.io/badge/Add%20to-Obtainium-4A90E2?logo=android&logoColor=white)](https://apps.obtainium.imranr.dev/redirect?r=obtainium%3A%2F%2Fadd%2Fhttps%3A%2F%2Fgithub.com%2Fkhonager%2FTrace)

The button adds this GitHub repository as Trace's update source. Obtainium can
install it as soon as an Android APK is attached to a GitHub Release.

Web end-to-end encryption uses the checked-in vodozemac bundle in `web/pkg`.
Deploy the web build over HTTPS. Hosts may also need COOP/COEP response headers
for browsers that require cross-origin isolation for WebAssembly threads.

Without Nix, install Flutter 3.41 or newer, Rust through `rustup`, and the
platform toolchains, then run the same Flutter commands. Rust is required to
build the vodozemac encryption library.

## Status

This is an early Matrix chat alpha rather than a production messenger.
Password and browser SSO login, session restore, encrypted room history,
pagination, text/file sending, invitations, room/user/cached-message search,
room creation and joining, Saved Messages, basic message actions, typing,
receipts, and encryption recovery are wired.
Push notifications, polished media rendering, production signing/branding, QR
verification, and encrypted-at-rest browser storage remain open.

The Matrix SDK stores its native cache in SQLite and its web cache in IndexedDB.
End-to-end encrypted event bodies remain ciphertext in that cache, but account
metadata and access credentials are not transparently database-encrypted by the
SDK on every target. Do not describe the current builds as offering full local
database encryption.
