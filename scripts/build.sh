#!/usr/bin/env bash
# Builds the Chymaera Linux ISO. Must run on Arch Linux (bare metal, VM, or
# an archlinux Docker container) as root or via sudo — mkarchiso requires it.
#
# What this does, in order:
#   1. Ensures packages/sarina (the Sarina submodule) is checked out.
#   2. Installs BlackArch's signing key + mirrorlist on this build host, via
#      BlackArch's own strap.sh, if not already present.
#   3. Runs mkarchiso against profile/, with the [chymaera] repo path in
#      pacman.conf substituted to an absolute path in a work copy (the
#      checked-in profile/pacman.conf stays portable across checkouts).
#
# NOTE: this script must run as root (mkarchiso requires it), but makepkg
# refuses to run as root — so run scripts/build-local-packages.sh as a
# regular user FIRST to populate repo/x86_64/, then run this script.
#
# Output: out/*.iso

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$repo_root/work"
out_dir="$repo_root/out"
profile_build_dir="$work_dir/profile"

if [[ $EUID -ne 0 ]]; then
  echo "error: run as root (mkarchiso requires it), e.g.: sudo ./scripts/build.sh" >&2
  exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "error: mkarchiso not found — install archiso: pacman -S --needed archiso" >&2
  exit 1
fi

echo "==> Checking submodules"
git -C "$repo_root" submodule update --init --recursive

if [[ ! -f /etc/pacman.d/blackarch-mirrorlist ]]; then
  echo "==> Installing BlackArch keyring/mirrorlist on build host"
  curl -fsSL https://blackarch.org/strap.sh -o /tmp/blackarch-strap.sh
  bash /tmp/blackarch-strap.sh
else
  echo "==> BlackArch mirrorlist already present, skipping strap.sh"
fi

if ! compgen -G "$repo_root/repo/x86_64/chymaera.db*" >/dev/null; then
  echo "error: local [chymaera] repo not found at repo/x86_64/" >&2
  echo "  run scripts/build-local-packages.sh as a regular user first." >&2
  exit 1
fi

echo "==> Preparing work copy of profile/"
rm -rf "$profile_build_dir"
mkdir -p "$work_dir"
cp -r "$repo_root/profile" "$profile_build_dir"
sed -i "s|@@CHYMAERA_REPO_DIR@@|$repo_root/repo/x86_64|g" "$profile_build_dir/pacman.conf"

echo "==> Running mkarchiso"
mkdir -p "$out_dir"
mkarchiso -v -w "$work_dir/iso" -o "$out_dir" "$profile_build_dir"

echo "==> Done: $out_dir"
