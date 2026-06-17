{ pkgs, ... }:

let
  manifestUrl = "localhost/manifest.json";
  baseUrl = "localhost/patches";
  stateDir = "/var/lib/patch-runner";

in {
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 root root -"
  ];

  system.activationScripts.patchRunner = {
    deps = [ "users" "groups" ];
    text = ''
      set -euo pipefail

      STATE_FILE="${stateDir}/version"
      mkdir -p ${stateDir}

      local_version=0
      [[ -f "$STATE_FILE" ]] && local_version=$(cat "$STATE_FILE")

      echo "patch-runner: local version $local_version"

      manifest=$(${pkgs.curl}/bin/curl -fsSL "${manifestUrl}" 2>/dev/null || true)
      if [[ -z "$manifest" ]]; then
        echo "patch-runner: manifest not found"
        exit 0
      fi

      remote_version=$(echo "$manifest" | ${pkgs.jq}/bin/jq -r '.latest')

      if [[ "$remote_version" -le "$local_version" ]]; then
        echo "patch-runner: nothing to apply"
        exit 0
      fi

      echo "$manifest" \
        | ${pkgs.jq}/bin/jq -r \
            --argjson from "$local_version" \
            '.patches[] | select(.id > $from) | [.id, .file] | @tsv' \
        | sort -n \
        | while IFS=$'\t' read -r id file; do
            echo "patch-runner: applying patch $id ($file)"
            tmp=$(${pkgs.coreutils}/bin/mktemp)
            ${pkgs.curl}/bin/curl -fsSL "${baseUrl}/$file" -o "$tmp"
            bash "$tmp"
            rm "$tmp"
            echo "$id" > "$STATE_FILE"
          done
    '';
  };
}
