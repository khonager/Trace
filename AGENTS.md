# Trace agent instructions

Trace follows the shared product, design/UX, engineering, and release principles
in the sibling `core` repository and at `https://github.com/khonager/core`.
Read the relevant Core document before making a material cross-project decision.
Trace's local documentation wins when it records an intentional exception.

## Repository model

- `main` is the stable source line.
- `unstable` is the active integration and development-build line.
- Stable tags use `vMAJOR.MINOR.PATCH` and must match `pubspec.yaml`.
- Do not publish a debug-signed APK as a GitHub Release.

## Required checks

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

For Android or build-system changes, also verify:

```sh
flutter build apk --release
```

The local Nix Flutter wrapper can occasionally retain an engine-incompatible
shader cache. If widget tests report an `ink_sparkle.frag` runtime-stage format
mismatch, run `flutter clean` and repeat the checks before diagnosing app code.

