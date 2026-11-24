# Sourced by service scripts: sets REPO and the homelab settings (DATA_ROOT, DOMAIN, ...).
REPO="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
eval "$("$REPO/scripts/homelab" env | awk '{ printf "%s=%s\n", $1, ($2 == "" ? "\"\"" : "\x27" $2 "\x27") }')"
