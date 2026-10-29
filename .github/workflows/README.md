# Automated branch plumbing

- `.github/workflows/update-flake.yml` keeps `flake.lock` fresh and moves `testing`
  onto `main` with a 48-hour lag.
- `.github/workflows/backmerge-futures.yml` mirrors every merge into `main` onto
  `futures`, keeping that branch's own `flake.lock`.

## Branch model

```
futures (unstable) → dev → testing → main
```

`testing` is the soak branch. It carries the daily `flake.lock` bump **and** every
other change being tried out. `main` is `testing` with 48 hours of delay — nothing
reaches `main` that has not spent 48 hours on `testing` first.

`futures` is the unstable lane: same tree as `main`, but with
`nixpkgs.follows = "nixpkgs-unstable"` and therefore its own `flake.lock`. It is
kept in sync by a back-merge whenever `main` moves.

## Daily cycle (02:00 UTC)

Two jobs run in order on `schedule` and `workflow_dispatch`.

### 1. `promote` — `testing` → `main`

1. Look for an open PR `testing` → `main`.
2. Age gate: the PR must be older than 48 h (`SOAK_HOURS`). Skipped when the
   workflow is dispatched with `force_promote: true`.
3. Check gate: the `check` status on the PR head must be `SUCCESS`.
4. Topology gate: `main` must be an ancestor of `testing`. If the branches
   diverged the job **fails** rather than merging — reconcile by hand.
5. Fast-forward: `git push origin origin/testing:refs/heads/main`.
   GitHub then closes the PR as *merged* on its own.

The promotion is deliberately a fast-forward, never a squash. A squash would put a
commit on `main` that does not exist on `testing`; `main` would stop being an
ancestor of `testing` and step 4 would abort every subsequent cycle. Fast-forward
keeps `main` a strict prefix of `testing`, which *is* the definition of the
48-hour lead.

### 2. `update` — bump `flake.lock` on `testing`

Runs after `promote` (`needs: promote`) so the new PR is cut against a fresh `main`.

1. Check out `testing`.
2. `nix flake update`.
3. `nix flake check` — **blocking**. A broken lock never reaches `testing`; the
   workflow run just goes red.
4. If `flake.lock` changed: commit and push to `testing`. Never force-pushed —
   on rejection the step rebases onto `origin/testing` and retries, up to 3 times.
5. If `testing` is ahead of `main` and no promotion PR is open, open one
   (`--base main --head testing`, labels `dependencies,automated`).

Only one promotion PR exists at a time. An open PR keeps aging toward its merge and
automatically picks up every later push to `testing`, so the effective promotion
cadence is one every 48 h while `flake.lock` moves daily.

### `check` — validation job

Runs on every `pull_request` targeting `main`, which in practice means the
promotion PR. It is the status check the `promote` gate reads by name.

`nix flake check` must stay a **building** check — never `--no-build`.
`checks.<system>.gnome-shell-app-folder-order-patch` (see `flake.nix`) is what
proves the gnome-shell patch in `modulixos/desktop/gnome/patches/` still applies
to the bumped nixpkgs. A `--no-build` run only evaluates, so a patch that stopped
applying would pass the gate and break every rebuild.

## Back-merge into `futures`

`.github/workflows/backmerge-futures.yml` runs on every push to `main` — the
scheduled fast-forward above, an early manual merge of the promotion PR, or any
other merge into `main` — and on `workflow_dispatch`.

It merges `main` into `futures` and **always keeps `futures`'s own `flake.lock`**.
`futures` pins `nixpkgs.follows = "nixpkgs-unstable"` in its `flake.nix`, so its
lock resolves to completely different store paths; taking `main`'s lock would
undo the whole point of the branch. A `flake.lock` conflict therefore happens on
every single merge and is not an error — the lock is restored from the pre-merge
`futures` tip and staged.

Behaviour:

| Situation | Result |
|---|---|
| `futures` already contains `main` | no-op, exit 0 |
| Conflict on `flake.lock` only | resolved to `futures`'s lock, merge commit pushed |
| Conflict anywhere else | `git merge --abort`, job **fails** — resolve by hand |

`futures` is the unstable lane, so the merge commit is pushed straight to it: no
PR, and no `nix flake check` gate. Note that `futures`'s own `flake.lock` is never
bumped automatically; refresh it by hand when you want a newer `nixpkgs-unstable`.

`dev` sits between `futures` and `testing` in the branch chain and is **not**
back-merged by any workflow.

## Rejecting an update

Two ways, both honoured by the workflow:

- **Push a revert onto `testing`.** The PR tracks the branch head, so the revert
  neutralises the bad change inside the open PR without closing it. The rest of
  `testing` still promotes on schedule.
- **Close the PR.** The promotion is cancelled. The next daily run reopens a PR
  from whatever `testing` looks like then — so remove the offending commit from
  `testing` too, otherwise it comes back.

## Required configuration

### Secret

`FLAKE_BOT_TOKEN` — fine-grained PAT, *Resource owner* `Modulix-OS`, *Repository
access* limited to `Modulix-OS/mxpkgs`:

| Permission | Level |
|---|---|
| Contents | Read and write |
| Pull requests | Read and write |

Added under *Settings → Secrets and variables → Actions*. The name is
case-sensitive.

A user PAT is structural here, not a convenience: `GITHUB_TOKEN` never triggers
workflows, so a promotion PR opened with it would never start the `check` job — the
green-check gate in `promote` could never be satisfied — and the fast-forward push
to `main` would never chain into `backmerge-futures.yml`.

Two things that bite:

- **Organisation approval.** A fine-grained PAT aimed at an org-owned repository has
  to be approved by the org unless `Modulix-OS` enabled default access
  (*Org settings → Personal access tokens → Settings*). A token left `pending`
  exists but every request is refused, which shows up as a 403 rather than a missing
  secret. Approve it under *Pending requests*, or fall back to a **classic PAT** with
  the `repo` + `workflow` scopes, which needs no approval.
- **Expiry.** GitHub warns by email beforehand, but on expiry day the CI breaks again
  with `Error: Input required and not supplied: token` -- `actions/checkout` reads
  its `token` input as required, so an unset or expired-and-removed secret renders
  as an empty string.

Its owner must sit in the **branch-protection bypass allowlist** of `main`,
otherwise the fast-forward push in `promote` is rejected. `testing` must either be
unprotected or list the same user in its bypass allowlist, since `update` pushes
to it directly.

### Repository settings

- *Settings → General*: default branch is `main`. `schedule` and
  `workflow_dispatch` only ever read the workflow file from the default branch, so
  the cron does not arm until the workflows live on `main`.
- *Settings → General → Pull Requests*: keep **Allow merge commits** enabled so an
  early manual merge from the UI stays consistent with the model. Do **not**
  restrict the repo to squash-only — a squash would put a commit on `main` that is
  absent from `testing` and permanently break the fast-forward gate.
- *Settings → Branches → `main`*: `check` is a good required status check.

## Knobs

| What | Where |
|---|---|
| Schedule | `on.schedule.cron`, currently `0 2 * * *` (02:00 UTC = 03:00 Paris in winter, 04:00 in summer — GitHub cron has no DST handling) |
| Soak window | `env.SOAK_HOURS`, currently `48` |
| Branches | `env.SRC_BRANCH` / `env.DST_BRANCH` |

## Manual runs

*Actions → Update Flake Lock → Run workflow*:

- `force_promote: false` — normal cycle, honours the 48 h gate.
- `force_promote: true` — promotes the open PR immediately (check gate and
  topology gate still apply).

## Troubleshooting

**`promote` fails with "branches diverged"**
`main` is no longer an ancestor of `testing`, usually because something was merged
into `main` directly or `testing` was rewritten. Fix the topology by hand
(`git merge main` into `testing`, or reset `main` onto `testing`) before the next run.

**`promote` logs "flake check not green"**
The promotion PR's `check` job is red or still running. Nothing is merged; the next
run retries.

**`update` fails on `nix flake check`**
The upstream bump genuinely breaks the build. `testing` is untouched. Investigate
the failing derivation — often the gnome-shell patch no longer applies.

**`update` fails after 3 push attempts**
Concurrent writes to `testing` that conflict on `flake.lock`. Resolve manually,
then re-dispatch.

**"Resource not accessible by integration"**
`FLAKE_BOT_TOKEN` is missing, expired, or lacks Contents/Pull requests write.

## Other workflows

`patches-manifest.yml` verifies that `patches/manifest.json` stays in sync with the
patch files. It only verifies, never commits, so it cannot invalidate the detached
minisign signature.
