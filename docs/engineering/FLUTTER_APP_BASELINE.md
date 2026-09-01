# Flutter application baseline

This is the local reference for the conventions that should eventually live in
the public `khonager/core` repository. Product-specific choices remain in each
application repository; shared engineering policy belongs in Core.

## Repository model

- Keep `main` releasable and protect it with pull requests and passing checks.
- Integrate active work on `unstable`; use short-lived feature branches when a
  change benefits from isolated review.
- Treat stable `vMAJOR.MINOR.PATCH` tags as immutable.
- Give development builds unique SemVer prerelease versions such as
  `v1.4.0-dev.238`.
- Keep app versions in `pubspec.yaml`; workflows validate rather than invent
  the stable version.

## Continuous integration

- Pin Flutter and Java explicitly and cache Flutter dependencies.
- Run formatting, analysis, and tests independently from platform packaging.
- Build on pull requests, `main`, and `unstable`; publish only trusted pushes.
- Upload build artifacts with explicit retention and fail when expected output
  is missing.
- Pass public build configuration through repository variables and sensitive
  values through secrets. Remember that client-side identifiers are embedded
  in the resulting app even when GitHub masks them.

## Android releases

- Use a dedicated per-app release key. Never establish a public update channel
  with Flutter's shared debug key.
- Keep the keystore out of Git and back it up separately from GitHub.
- Require all signing inputs together and fail closed for tagged releases.
- Publish unstable builds as prereleases and stable version tags as releases.
- Keep the Android application ID stable after the first public build.

## Product and UX baseline

- Write a short product brief before implementation: user, problem, promise,
  explicit non-goals, supported platforms, and privacy posture.
- Prefer platform conventions, accessible semantics, keyboard support, reduced
  motion, and responsive layouts before ornamental motion or custom controls.
- Define loading, empty, offline, partial-success, error, and destructive-action
  states for every user-facing flow.
- Keep protocol, persistence, and platform code behind boundaries so visual
  redesigns do not require rewriting core behavior.
- Record material design decisions and revisit them with screenshots and user
  evidence instead of relying on taste alone.

## Public repository checklist

- Add an intentional license compatible with every shipped dependency.
- Document setup, supported platforms, release channels, security reporting,
  privacy-relevant integrations, and known limitations.
- Add contribution and code-of-conduct files when outside contributions become
  welcome; do not imply that they are accepted before there is capacity.
- Enable secret scanning, dependency updates, branch protection, and least-
  privilege workflow permissions.
- Never commit signing keys, service credentials, production `.env` files, or
  generated build outputs.

