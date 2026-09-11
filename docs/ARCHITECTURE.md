# Architecture

## Layers

1. **Base**: Arch Linux, built via [archiso](https://github.com/archlinux/archiso).
   `profile/` is a fork of archiso's `releng` profile (`profiledef.sh`,
   `packages.x86_64`, `pacman.conf`), kept close to upstream so Arch's own
   install/live-boot support (hardware drivers, `archinstall`, rescue tools)
   isn't quietly lost to hand-trimming.
2. **Security tooling**: [BlackArch](https://github.com/BlackArch/blackarch),
   added as a repo (`[blackarch]` in `profile/pacman.conf`) rather than
   forked. Installed via `blackarch-*` pacman category groups (e.g.
   `blackarch-webapp`, `blackarch-scanner`) instead of the `blackarch-full`
   metapackage — installing all ~2,800 tools at once is BlackArch's own
   documented way to break a system (conflicting binaries, competing Python
   environments, duplicate tool names).
3. **Desktop**: [KDE Plasma](https://github.com/kde/plasma-desktop) via the
   `plasma-meta` group + `sddm` + a small set of core apps (Dolphin, Konsole,
   Kate, Ark, Okular), plus NetworkManager/PipeWire for a normal desktop
   experience (`profile/packages.x86_64` layers these on top of releng's
   more CLI/live-boot-oriented networking and audio stack).
4. **AI agent**: [Chymaera Code Agent](https://github.com/chymaera3301/Chymaera_Code_Agent),
   a private repo vendored as a git submodule at `packages/agent`, packaged
   for the ISO by `packages/pkgbuilds/chymaera-code-agent-git`.

## Why curated BlackArch categories, not `blackarch-full`

Kali ships a curated default tool set (`kali-linux-default`) rather than
every tool in its repos, precisely to keep the base system usable and
supportable. Chymaera follows the same idea on top of BlackArch's category
groups. The category list currently in `profile/packages.x86_64` is a
**first-pass guess**, not a validated set — see the next section.

## Validating the tool selection: `blackarch_compat`

The agent submodule ships a purpose-built harness for exactly this problem,
at `packages/agent/blackarch_compat/`: it installs one `blackarch-*` category
(or an explicit combination, with `--combo`) at a time inside a disposable
Docker container and records whether the install goes cleanly — catching
conflicting packages/dependency resolution failures before any specific
combination is baked into `profile/packages.x86_64`.

```bash
cd packages/agent
python3 -m blackarch_compat.run_tests --all -o report.json --markdown report.md
```

As of this writing that harness is unit-tested but **has not been run
against a real Docker daemon** (see its own README's Status section) — run
it and sanity-check a few categories by hand before trusting its results,
and before treating the current `profile/packages.x86_64` BlackArch section
as anything more than a starting point.

What it catches: install-time conflicts (`pacman -S` failures, `pacman -Qk`
file-manifest mismatches). What it doesn't: runtime conflicts between tools
(port/config/venv collisions), or anything that only shows up on the actual
built ISO — for that, a local [archiso](https://github.com/archlinux/archiso)
checkout's `scripts/run_archiso.sh` boots a built ISO in QEMU.

## Package flow for the AI agent

```
packages/agent/            (git submodule, tracks Chymaera_Code_Agent)
        │
        ▼  scripts/build-agent-package.sh
packages/pkgbuilds/chymaera-code-agent-git/PKGBUILD
        │  (makepkg, run as a regular user)
        ▼
repo/x86_64/*.pkg.tar.zst + chymaera.db   (local pacman repo, gitignored)
        │
        ▼  scripts/build.sh → mkarchiso, using profile/pacman.conf's [chymaera] repo
out/*.iso
```

Advancing the agent to a new commit is:

```bash
./scripts/update-agent.sh   # git submodule update --remote --merge, staged
git commit -m "Update Chymaera Code Agent"
```

The distro repo's `packages/pkgbuilds/chymaera-code-agent-git/PKGBUILD`
builds directly from whatever commit `packages/agent` is checked out to —
no tagged release needed for local/dev/CI builds. The AUR-facing PKGBUILD
that builds from tagged release tarballs lives upstream, in the agent repo
itself, at `packaging/arch/PKGBUILD`, and is the source of truth for the
systemd unit, sysusers snippet, and env file both PKGBUILDs install.

## Open questions / not yet decided

- Final BlackArch category list (pending `blackarch_compat` results).
- Whether `archinstall` gets a Chymaera-branded profile/config, or ships
  as-is for now.
- Live-session auth model (autologin vs. SDDM login prompt with a set
  password) — not yet configured in `profile/airootfs`.
- Branding: ISO/desktop theming, wallpaper, SDDM theme, Plasma look-and-feel
  package — none of this exists yet.
