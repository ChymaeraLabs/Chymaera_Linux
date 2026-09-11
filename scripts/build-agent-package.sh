#!/usr/bin/env bash
# Builds chymaera-code-agent-git from the packages/agent submodule and adds
# it to the local [chymaera] pacman repo at repo/x86_64/. Run this before
# scripts/build.sh (which calls it automatically) whenever packages/agent
# has moved to a new commit.
#
# Requires: Arch Linux (or an Arch container), base-devel, git.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "error: makepkg refuses to run as root — run this as a regular user" >&2
  echo "  (it uses sudo internally for any pacman dependency installs it needs)." >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pkgbuild_dir="$repo_root/packages/pkgbuilds/chymaera-code-agent-git"
repo_dir="$repo_root/repo/x86_64"

if [[ ! -f "$repo_root/packages/agent/pyproject.toml" ]]; then
  echo "error: packages/agent submodule looks empty — run:" >&2
  echo "  git submodule update --init --recursive" >&2
  exit 1
fi

mkdir -p "$repo_dir"

(
  cd "$pkgbuild_dir"
  rm -rf pkg src
  makepkg -f -s --noconfirm
  cp -f ./*.pkg.tar.zst "$repo_dir/"
)

repo-add "$repo_dir/chymaera.db.tar.gz" "$repo_dir"/*.pkg.tar.zst

echo "Built and added to local repo: $repo_dir"
