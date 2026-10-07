#!/usr/bin/env bash
# One-command local demo: installs deps (first run), builds the Flutter web app,
# and serves app + API at http://localhost:8000
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -d backend/.venv ]; then
  python3 -m venv backend/.venv
  backend/.venv/bin/pip install -q --upgrade pip
  backend/.venv/bin/pip install -q -r backend/requirements.txt
fi

if [ "${SKIP_WEB_BUILD:-0}" != "1" ]; then
  (cd app && flutter pub get >/dev/null && flutter build web --release --no-wasm-dry-run)
fi

cd backend
echo "LifeStep running at http://localhost:8000  (Ctrl+C to stop)"
exec .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
