# Trace

Trace is groundwork for a privacy-first Matrix client built with Flutter. The
initial targets are Android, iOS, and Linux. Product features are kept behind
domain and platform boundaries so the visual interface can be redesigned
without rewriting protocol code.

The client uses the Dart Matrix SDK with vodozemac end-to-end encryption. The
SDK is AGPL-3.0-or-later; see the architecture notes before distributing a
combined application.

The repository currently contains an interactive chat prototype backed by mock
data; the Matrix adapter is not connected to the presentation layer yet. See
[`docs/product/PRODUCT_BRIEF.md`](docs/product/PRODUCT_BRIEF.md) for the agreed
scope and [`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md)
for the dependency rules. The ordered work required for a usable Matrix build
is tracked in [`docs/product/ALPHA_CHECKLIST.md`](docs/product/ALPHA_CHECKLIST.md).

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

This is a visual and architectural prototype, not a usable Matrix client yet.
Encrypted database implementations, Matrix session composition, production
identifiers, branding, and distributable signing remain unresolved.
