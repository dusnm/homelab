#!/bin/sh
# Create or replace the Authelia user. Prompts for the password (never stored in shell
# history), hashes it with Authelia's own tool and writes $DATA_ROOT/authelia/config/users.yml.
#   services/authelia/add-user.sh <username> <email> "<Display Name>"
set -eu
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib.sh"
[ $# -eq 3 ] || { echo "usage: $0 <username> <email> \"<Display Name>\"" >&2; exit 1; }
image=$(sed -n 's/^ *image: *\([^ ]*\).*/\1/p' "$REPO/services/authelia/compose.yml")
umask 077
mkdir -p "$DATA_ROOT/authelia/config"
out=$(mktemp)
trap 'rm -f "$out"' EXIT
echo "Choose the password for $1 (typed twice, nothing is shown while typing):"
docker run --rm -it "$image" authelia crypto hash generate argon2 | tee "$out"
hash=$(tr -d '\r' < "$out" | sed -n 's/^Digest: //p')
[ -n "$hash" ] || { echo "hashing failed (passwords didn't match?)" >&2; exit 1; }
cat > "$DATA_ROOT/authelia/config/users.yml" <<YAML
users:
  $1:
    disabled: false
    displayname: '$3'
    email: '$2'
    password: '$hash'
    groups: [admins]
YAML
echo "Wrote $DATA_ROOT/authelia/config/users.yml for $1. Restart Authelia: homelab restart authelia"
