#!/usr/bin/env bash
# Example hotfix patch. Runs as root, once, when its id becomes the newest
# unapplied patch. MUST be idempotent: it may be retried after a partial run.
#
# Id 1 is reserved as the bootstrap example; replace its body with a real
# hotfix or keep it as a no-op smoke test.
set -euo pipefail

echo "patch 0001: example hotfix applied"
