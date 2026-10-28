#!/usr/bin/env bash
set -euo pipefail
busctl --system --timeout=3600 call org.modulix.Daemon /org/modulix/Daemon org.modulix.Daemon UpdateHardware
