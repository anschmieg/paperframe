#!/usr/bin/env bash
set -euo pipefail

PR="${1:-$(gh pr list --state open --json number --jq 'max_by(.number).number')}"
MERGE="${MERGE:-0}"

BRANCH="$(gh pr view "$PR" --json headRefName --jq '.headRefName')"

echo "== Review flow for PR #$PR =="
echo "Branch: $BRANCH"

export PATH="$HOME/.swiftly/bin:$PATH"
hash -r

echo "[1/10] Verify Swift toolchain"
which swift
swift --version

echo "[2/10] Fail fast on dirty working tree"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ABORT -- working tree is dirty. Commit, stash, or discard changes first."
  exit 1
fi

echo "[3/10] Refresh refs"
git fetch --prune origin

echo "[4/10] Baseline on main"
git checkout main
git pull --ff-only origin main
git status -sb
swift test

echo "[5/10] Check out PR branch"
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH" "origin/$BRANCH"
fi

echo "[6/10] Refresh PR branch"
git pull --ff-only origin "$BRANCH"
git status -sb

echo "[7/10] Run full tests on PR branch"
swift test

echo "[8/10] Stop here unless merge requested"
if [[ "$MERGE" != "1" ]]; then
  echo "Review passed for PR #$PR. Re-run with MERGE=1 to merge."
  exit 0
fi

echo "[9/10] Merge and verify"
git checkout main
git pull --ff-only origin main
git merge --ff-only "$BRANCH"
swift test

echo "[10/10] Push and clean up"
git push origin main
git branch -d "$BRANCH"
git push origin --delete "$BRANCH" || true

echo "PR #$PR merged successfully."
