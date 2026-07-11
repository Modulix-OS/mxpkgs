{ config, lib, pkgs, ... }:

let
  cfg = config.mx.services.patch-runner;

  base =
    if cfg.baseUrl != null then cfg.baseUrl
    else "https://raw.githubusercontent.com/${cfg.repo}/${cfg.ref}/patches";

  runner = pkgs.writeShellApplication {
    name = "patch-runner";
    runtimeInputs = with pkgs; [ curl jq coreutils minisign ];
    text = ''
      # Config injected via the service environment.
      : "''${BASE:?missing BASE}"
      : "''${PUBKEY=}"
      state="''${STATE_DIRECTORY:?missing STATE_DIRECTORY}/version"

      applied=0
      if [ -f "$state" ]; then
        applied=$(cat "$state")
      fi

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      # Enforce TLS for https targets; allow plain http only when explicitly used
      # (e.g. a local test server). Never downgrade an https URL.
      curl_opts=( --connect-timeout 10 --max-time 60 -fsSL )
      case "$BASE" in
        https://*) curl_opts+=( --proto '=https' --tlsv1.2 ) ;;
      esac
      curl_get() { curl "''${curl_opts[@]}" "$@"; }

      if ! curl_get -o "$tmp/manifest.json" "$BASE/manifest.json"; then
        echo "patch-runner: manifest unavailable, skipping"
        exit 0
      fi

      if [ -n "$PUBKEY" ]; then
        if ! curl_get -o "$tmp/manifest.json.minisig" "$BASE/manifest.json.minisig"; then
          echo "patch-runner: signature required but missing, aborting" >&2
          exit 1
        fi
        minisign -V -P "$PUBKEY" \
          -m "$tmp/manifest.json" -x "$tmp/manifest.json.minisig"
      fi

      latest=$(jq -r '.latest' "$tmp/manifest.json")
      if ! [[ "$latest" =~ ^[0-9]+$ ]]; then
        echo "patch-runner: invalid manifest (.latest='$latest')" >&2
        exit 1
      fi

      if [ "$latest" -le "$applied" ]; then
        echo "patch-runner: up to date (version $applied)"
        exit 0
      fi

      jq -r --argjson from "$applied" \
        '.patches[] | select(.id > $from) | [.id, .file, (.sha256 // "")] | @tsv' \
        "$tmp/manifest.json" \
        | sort -n \
        | while IFS=$'\t' read -r id file sha; do
            if [ -z "$sha" ]; then
              echo "patch-runner: patch $id has no sha256, aborting" >&2
              exit 1
            fi
            curl_get -o "$tmp/patch" "$BASE/$file"
            actual=$(sha256sum "$tmp/patch" | cut -d' ' -f1)
            if [ "$actual" != "$sha" ]; then
              echo "patch-runner: HASH MISMATCH patch $id (expected $sha, got $actual), aborting" >&2
              exit 1
            fi
            echo "patch-runner: applying patch $id ($file)"
            bash "$tmp/patch"
            echo "$id" > "$state"
          done
    '';
  };

in
{
  options.mx.services.patch-runner = {
    enable = lib.mkEnableOption "Modulix OS remote hotfix runner";

    repo = lib.mkOption {
      type = lib.types.str;
      default = "qhorgues/Modulix-OS";
      description = "GitHub owner/repo hosting the patches/ directory.";
    };

    ref = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git ref (branch, tag, or commit) to fetch patches from. Pin a commit for immutability.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Full base URL of the patches directory (overrides repo/ref).
        Must expose manifest.json (and the patch files) underneath.
        Plain http:// is allowed only for local testing.
      '';
    };

    publicKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        minisign public key. When set, the manifest signature
        (manifest.json.minisig) is fetched and verified before any patch runs.
        Strongly recommended for production use.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar expression for the periodic check.";
    };

    runOnActivation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also trigger a (non-blocking) patch check after each system activation.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.patch-runner = {
      description = "Modulix OS remote hotfix runner";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe runner;
        User = "root";
        StateDirectory = "patch-runner";
        StateDirectoryMode = "0700";
        TimeoutStartSec = 300;

        Environment = [
          "BASE=${base}"
          "PUBKEY=${lib.optionalString (cfg.publicKey != null) cfg.publicKey}"
        ];

        # Patches mutate the running system, so strict confinement (ProtectSystem,
        # NoNewPrivileges) is not applicable; apply what is compatible.
        PrivateTmp = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
      };
    };

    systemd.timers.patch-runner = {
      description = "Periodic Modulix OS hotfix check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = 600;
      };
    };

    # Pure trigger, no inline logic: safe inside activation.
    system.activationScripts.patchRunnerTrigger = lib.mkIf cfg.runOnActivation {
      text = ''
        ${config.systemd.package}/bin/systemctl start --no-block patch-runner.service || true
      '';
    };
  };
}
