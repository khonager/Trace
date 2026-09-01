#!/usr/bin/env bash

set -euo pipefail

if [ "$(git branch --show-current)" != "main" ]; then
  echo "Stable releases must be created from main." >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "The working tree must be clean before creating a release tag." >&2
  exit 1
fi

git fetch origin main --tags

if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
  echo "Local main must exactly match origin/main before releasing." >&2
  exit 1
fi

VERSION=$(sed -n 's/^version:[[:space:]]*\([^+]*\).*/\1/p' pubspec.yaml | head -n 1)
TAG="v$VERSION"

if [ -z "$VERSION" ]; then
  echo "Could not read the application version from pubspec.yaml." >&2
  exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists. Bump pubspec.yaml before releasing." >&2
  exit 1
fi

git tag -a "$TAG" -m "Trace $VERSION"
git push origin "$TAG"
echo "Pushed $TAG. GitHub Actions will build and publish the release."

