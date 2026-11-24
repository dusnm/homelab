#!/bin/sh
# Create Authelia's two secrets in $DATA_ROOT/authelia/secrets (once; existing ones are kept).
set -eu
. "$(dirname "$(readlink -f "$0")")/../../scripts/lib.sh"
dir="$DATA_ROOT/authelia/secrets"
mkdir -p "$dir" && chmod 700 "$dir"
for f in jwt_secret storage_encryption_key; do
    if [ -s "$dir/$f" ]; then echo "keeping $dir/$f"; continue; fi
    (umask 077; openssl rand -hex 64 > "$dir/$f")
    echo "created $dir/$f"
done
