#!/usr/bin/env bash
# Build the Flutter web app and copy it to deploy/web (the folder the hosted server serves).
# Run this after changing anything in app/, then commit deploy/web.
set -euo pipefail
cd "$(dirname "$0")/.."
(cd app && flutter pub get >/dev/null && flutter build web --release --no-wasm-dry-run)
rm -rf deploy/web && mkdir -p deploy && cp -R app/build/web deploy/web
echo "Copied app/build/web -> deploy/web"
