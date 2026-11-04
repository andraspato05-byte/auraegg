#!/usr/bin/env bash
# Downloads the pinned Rojo, selene and Lune binaries (Linux x86_64) into .tools/bin.
# Used by CI. On your own computer you can instead use Rokit/Aftman with aftman.toml.
set -euo pipefail
cd "$(dirname "$0")/.."

ROJO_VERSION=7.4.4
SELENE_VERSION=0.31.0
LUNE_VERSION=0.11.1

BIN="$PWD/.tools/bin"
mkdir -p "$BIN"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() { # name url
	echo "installing $1"
	curl -fsSL "$2" -o "$TMP/$1.zip"
	unzip -o -q "$TMP/$1.zip" -d "$TMP/$1"
	find "$TMP/$1" -type f -name "$1" -exec cp {} "$BIN/$1" \;
	chmod +x "$BIN/$1"
}

fetch rojo "https://github.com/rojo-rbx/rojo/releases/download/v${ROJO_VERSION}/rojo-${ROJO_VERSION}-linux-x86_64.zip"
fetch selene "https://github.com/Kampfkarren/selene/releases/download/${SELENE_VERSION}/selene-${SELENE_VERSION}-linux.zip"
fetch lune "https://github.com/lune-org/lune/releases/download/v${LUNE_VERSION}/lune-${LUNE_VERSION}-linux-x86_64.zip"

if [[ -n "${GITHUB_PATH:-}" ]]; then
	echo "$BIN" >> "$GITHUB_PATH"
fi
echo "tools installed in $BIN"
