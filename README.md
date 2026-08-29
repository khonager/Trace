# Trace

Trace is groundwork for a privacy-first Matrix client built with Flutter. The
initial targets are Android, iOS, and Linux. Product features are kept behind
domain and platform boundaries so the visual interface can be redesigned
without rewriting protocol code.

The client uses the Dart Matrix SDK with vodozemac end-to-end encryption. The
SDK is AGPL-3.0-or-later; see the architecture notes before distributing a
combined application.

The repository intentionally contains only a placeholder screen. See
[`docs/product/PRODUCT_BRIEF.md`](docs/product/PRODUCT_BRIEF.md) for the agreed
scope and [`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md)
for the dependency rules.

## Development

With Nix flakes enabled:

```sh
nix develop
flutter pub get
flutter test
flutter analyze
```

Without Nix, install Flutter 3.41 or newer, Rust through `rustup`, and the
platform toolchains, then run the same Flutter commands. Rust is required to
build the vodozemac encryption library.

## Status

This is a non-visual foundation. Encrypted database implementations, production
identifiers, branding, and distributable signing are deliberately unresolved.
