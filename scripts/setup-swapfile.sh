#!/bin/sh
# Adds a swap file on the root filesystem and makes it permanent (fstab).
# Run with: sudo sh setup-swapfile.sh [SIZE]     (default 16G, e.g. 8G)
set -eu
SWAP=/swapfile
SIZE="${1:-16G}"

if [ -e "$SWAP" ]; then echo "$SWAP already exists, aborting"; exit 1; fi

fallocate -l "$SIZE" "$SWAP"
chmod 600 "$SWAP"
/sbin/mkswap "$SWAP"
/sbin/swapon --priority 10 "$SWAP"   # preferred over any swap partition (default priority -2)

grep -q "^$SWAP " /etc/fstab || echo "$SWAP none swap sw,pri=10 0 0" >> /etc/fstab

/sbin/swapon --show
free -h
