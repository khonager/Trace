# Trace

Trace is groundwork for a privacy-first Matrix client built with Flutter. The
initial targets are Android, iOS, and Linux. Product features are kept behind
domain and platform boundaries so the visual interface can be redesigned
without rewriting protocol code.

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

Without Nix, install Flutter 3.41 or newer plus the platform toolchains, then
run the same Flutter commands.

## Status

This is a non-visual foundation. Matrix SDK selection, production identifiers,
branding, and distributable signing are deliberately unresolved.
