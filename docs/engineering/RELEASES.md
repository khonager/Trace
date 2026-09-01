# Releases

Trace uses two long-lived branches and immutable stable version tags:

- `main` is the stable source line.
- `unstable` is the integration and development-build line.
- `vMAJOR.MINOR.PATCH` tags identify stable releases and must match the version
  in `pubspec.yaml` without its Flutter build number.
- Unstable pushes receive `vMAJOR.MINOR.PATCH-dev.RUN` prerelease tags when
  production Android signing is configured.

The Android workflow always uploads its APK as a short-lived Actions artifact.
It publishes GitHub Releases only for signed builds. This prevents a public,
debug-signed APK from establishing the wrong Android update identity. The
workflow also installs Rust because Trace's vodozemac encryption dependency
compiles native code during Android packaging.

## GitHub configuration

Configure these repository settings before expecting media search or published
releases:

| Kind | Name | Purpose |
| --- | --- | --- |
| Variable | `TRACE_MEDIA_SEARCH_ENDPOINT` | Public HTTPS URL of the Trace media-search relay. |
| Secret | `TRACE_GIPHY_API_KEY` | GIPHY client integration key embedded in the app. |
| Secret | `ANDROID_KEYSTORE_BASE64` | Base64-encoded dedicated Trace release keystore. |
| Secret | `ANDROID_KEYSTORE_PASSWORD` | Keystore password. |
| Secret | `ANDROID_KEY_PASSWORD` | Key password. |
| Secret | `ANDROID_KEY_ALIAS` | Signing-key alias. |

The GIPHY key is stored as a GitHub secret to avoid casual disclosure in logs,
but it is still an app identifier recoverable from a compiled client. Never put
the Brave Search backend credential in a Flutter build.

If all four Android signing secrets are absent, branch and pull-request builds
still produce a debug-signed Actions artifact. If only some are present, or a
stable tag is pushed without them, the workflow fails deliberately.

## Stable release

1. Merge the intended source into `main`.
2. Update `version:` in `pubspec.yaml` and commit it.
3. Confirm `main` is clean and pushed.
4. Run `./scripts/release.sh`.

The script creates an annotated `vMAJOR.MINOR.PATCH` tag. GitHub Actions checks
that the tag matches `pubspec.yaml` and points to a commit contained in `main`,
then builds and publishes the APK.

Do not publish Trace broadly until its application ID, branding, signing-key
backup, and AGPL corresponding-source/license obligations have all been settled.
