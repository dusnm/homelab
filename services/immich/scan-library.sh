#!/bin/sh
# Scan Immich external libraries through the API (the Immich CLI can't do this).
#   services/immich/scan-library.sh          scan every external library
#   services/immich/scan-library.sh stats    only show asset counts per library
# Needs an API key with library.read + library.update (+ library.statistics),
# stored on its own line in $DATA_ROOT/immich/.immich-api-key (chmod 600).
set -eu
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib.sh"
IMMICH=${IMMICH_URL:-http://127.0.0.1:2283}   # straight to the container, no nginx
KEY=$(cat "${IMMICH_API_KEY_FILE:-$DATA_ROOT/immich/.immich-api-key}")

api() { curl -sf -H "x-api-key: $KEY" -H "Accept: application/json" "$@"; }

api "$IMMICH/api/libraries" | python3 -c '
import json, sys
for lib in json.load(sys.stdin):
    print(lib["id"], lib["name"], ",".join(lib["importPaths"]) or "(no import path!)", sep="\t")
' | while IFS="$(printf '\t')" read -r id name paths; do
    if [ "${1:-}" != "stats" ]; then
        api -X POST "$IMMICH/api/libraries/$id/scan" -o /dev/null && echo "scan queued: $name ($paths)"
    fi
    api "$IMMICH/api/libraries/$id/statistics" | python3 -c '
import json, sys; s = json.load(sys.stdin)
print("  photos:", s.get("photos"), " videos:", s.get("videos"), " total:", s.get("total"))'
done
