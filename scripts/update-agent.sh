#!/usr/bin/env bash
# Advances packages/agent (the Chymaera Code Agent submodule) to the latest
# commit on its default branch and stages the pointer bump. Review with
# `git -C packages/agent log --oneline @{u}..` beforehand if you want to see
# what's changing first; commit the result yourself when it looks right.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

git -C "$repo_root" submodule update --remote --merge packages/agent
git -C "$repo_root" add packages/agent

echo "packages/agent advanced to:"
git -C "$repo_root/packages/agent" log -1 --oneline
echo
echo "Staged. Review with 'git diff --cached packages/agent' and commit when ready."
