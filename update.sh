#!/usr/bin/env bash
set -euo pipefail

FLAKE="flake.nix"
BASE_URL="https://ksa-linux.ahwoo.com"

# Get current version from flake.nix
CURRENT_VERSION=$(grep -oP 'version = "\K[0-9.]+' "$FLAKE")
echo "Current version: $CURRENT_VERSION"

# Fetch the latest version from the website
echo "Checking for updates..."
PAGE=$(curl -sfL "$BASE_URL/")
LATEST_VERSION=$(echo "$PAGE" | grep -oP 'setup_ksa_v\K[0-9.]+(?=\.tar\.gz)' | head -1)

if [ -z "$LATEST_VERSION" ]; then
    echo "ERROR: Could not determine latest version from website"
    exit 1
fi

echo "Latest version: $LATEST_VERSION"

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo "Already up to date!"
    exit 0
fi

URL="${BASE_URL}/download?file=setup_ksa_v${LATEST_VERSION}.tar.gz"

# Download and compute Nix hash
echo "Downloading tarball (~2 GB) and computing hash..."
NIX_HASH=$(nix-prefetch-url --type sha256 "$URL" 2>/dev/null)

if [ -z "$NIX_HASH" ]; then
    echo "ERROR: Failed to download or compute hash"
    exit 1
fi

# Convert to SRI format
SRI_HASH=$(nix hash to-sri --type sha256 "$NIX_HASH")

echo "New hash: $SRI_HASH"

# Update flake.nix
sed -i "s/version = \"${CURRENT_VERSION}\";/version = \"${LATEST_VERSION}\";/" "$FLAKE"
sed -i "s|hash = \"[^\"]*\";|hash = \"${SRI_HASH}\";|" "$FLAKE"

echo "Updated $FLAKE: $CURRENT_VERSION → $LATEST_VERSION"
