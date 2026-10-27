{ pkgs }:

pkgs.writeShellScript "patch-runner" ''
  set -euo pipefail

  : "''${BASE:?missing BASE}"
  : "''${PUBKEY=}"
  : "''${CURRENT_VERSION:=0}"
  state="''${STATE_DIRECTORY:?missing STATE_DIRECTORY}/version"

  applied=0
  if [ -f "$state" ]; then
    applied=$(cat "$state")
  fi
  if [ "$applied" -lt "$CURRENT_VERSION" ]; then
    applied=$CURRENT_VERSION
  fi

  tmp=$(${pkgs.coreutils}/bin/mktemp -d)
  trap '${pkgs.coreutils}/bin/rm -rf "$tmp"' EXIT

  curl_opts=( --connect-timeout 10 --max-time 60 -fsSL )
  case "$BASE" in
    https://*) curl_opts+=( --proto '=https' --tlsv1.2 ) ;;
  esac
  curl_get() { ${pkgs.curl}/bin/curl "''${curl_opts[@]}" "$@"; }

  if ! curl_get -o "$tmp/manifest.json" "$BASE/manifest.json"; then
    echo "patch-runner: manifest unavailable, skipping"
    exit 0
  fi

  if [ -n "$PUBKEY" ]; then
    if ! curl_get -o "$tmp/manifest.json.minisig" "$BASE/manifest.json.minisig"; then
      echo "patch-runner: signature required but missing, aborting" >&2
      exit 1
    fi
    ${pkgs.minisign}/bin/minisign -V -P "$PUBKEY" \
      -m "$tmp/manifest.json" -x "$tmp/manifest.json.minisig"
  fi

  latest=$(${pkgs.jq}/bin/jq -r '.latest' "$tmp/manifest.json")
  if ! [[ "$latest" =~ ^[0-9]+$ ]]; then
    echo "patch-runner: invalid manifest (.latest='$latest')" >&2
    exit 1
  fi

  if [ "$latest" -le "$applied" ]; then
    echo "patch-runner: up to date (version $applied)"
    exit 0
  fi

  ${pkgs.jq}/bin/jq -r --argjson from "$applied" \
    '.patches[] | select(.id > $from) | [.id, .file, (.sha256 // "")] | @tsv' \
    "$tmp/manifest.json" \
    | ${pkgs.coreutils}/bin/sort -n \
    | while IFS=$'\t' read -r id file sha; do
        if [ -z "$sha" ]; then
          echo "patch-runner: patch $id has no sha256, aborting" >&2
          exit 1
        fi
        curl_get -o "$tmp/patch" "$BASE/$file"
        actual=$(${pkgs.coreutils}/bin/sha256sum "$tmp/patch" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
        if [ "$actual" != "$sha" ]; then
          echo "patch-runner: HASH MISMATCH patch $id (expected $sha, got $actual), aborting" >&2
          exit 1
        fi
        echo "patch-runner: applying patch $id ($file)"
        ${pkgs.bash}/bin/bash "$tmp/patch"
        echo "$id" > "$state"
      done
''
