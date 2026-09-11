#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR/functions"
if [[ "${1:-}" == "set-sector" || "${1:-}" == "set-zone" ]]; then
  exec node scripts/map_edit.js "$@"
fi
exec node scripts/map_admin.js "$@"
