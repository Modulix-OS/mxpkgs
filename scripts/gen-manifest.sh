#!/usr/bin/env bash
# Regenerate patches/manifest.json from the patch files in patches/.
#
# Patch files MUST be named NNNN-description.sh where NNNN is a zero-padded,
# strictly increasing integer id. Ids are immutable: never renumber or rewrite
# a published patch, only append new ones.
#
# After running this, sign the manifest before committing:
#   minisign -Sm patches/manifest.json
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
patch_dir="$repo_root/patches"
manifest="$patch_dir/manifest.json"

cd "$patch_dir"

entries=()
latest=0
for f in $(printf '%s\n' [0-9]*-*.sh | sort -n); do
  [ -e "$f" ] || continue
  id=$(printf '%s' "$f" | sed -E 's/^0*([0-9]+)-.*/\1/')
  if ! [[ "$id" =~ ^[0-9]+$ ]]; then
    echo "gen-manifest: bad patch filename '$f' (expected NNNN-desc.sh)" >&2
    exit 1
  fi
  sha=$(sha256sum "$f" | cut -d' ' -f1)
  entries+=("$(jq -n --argjson id "$id" --arg file "$f" --arg sha "$sha" \
    '{id: $id, file: $file, sha256: $sha}')")
  (( id > latest )) && latest=$id
done

printf '%s\n' "${entries[@]}" \
  | jq -s --argjson latest "$latest" '{latest: $latest, patches: (. | sort_by(.id))}' \
  > "$manifest"

echo "gen-manifest: wrote $manifest (latest=$latest, ${#entries[@]} patches)"
