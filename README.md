# Chymaera Linux

Chymaera Linux is an Arch-based distribution built for security research and
penetration testing, combining:

- **[Arch Linux](https://archlinux.org/)** as the rolling-release base
- **[BlackArch](https://github.com/BlackArch/blackarch)** tooling, curated rather
  than fully mirrored, to keep the system stable instead of shipping every
  package in the BlackArch repo
- **[KDE Plasma](https://github.com/kde/plasma-desktop)** as the primary desktop
  environment
- **[Sarina](https://github.com/chymaera3301/Sarina)**, an AI coding/ops
  agent integrated directly into the OS

The goal is Kali-style organization, documentation, and out-of-the-box UX for
security tooling, on top of Arch's package freshness and BlackArch's tool
catalog — built and versioned in the open on GitHub, which BlackArch and Kali
do not do.

## Why another security distro?

Kali does a lot right: curated tool menus, consistent documentation, a
predictable release/support cadence. But Kali isn't developed in the open on
GitHub, and BlackArch (which *is* on GitHub) ships its full tool catalog by
default, which can make the base system less stable for daily use. Chymaera
aims to sit between them: an openly developed, Arch-based system with a
curated BlackArch tool selection, a polished KDE Plasma desktop, and an
AI agent built in to help with recon, scripting, and general system tasks.

## Repository layout

```
Chymaera_Linux/
├── profile/                  # archiso profile used to build the live/install ISO
│   ├── profiledef.sh         # ISO metadata (name, label, boot modes, etc.)
│   ├── packages.x86_64       # package list installed into the ISO/target system
│   ├── pacman.conf           # repo config: core/extra + [blackarch] + [chymaera]
│   └── airootfs/             # files overlaid onto the live system's root
├── packages/
│   ├── sarina/                # git submodule: Sarina source (private repo)
│   └── pkgbuilds/
│       └── sarina-git/        # PKGBUILD building packages/sarina locally
├── repo/                     # local pacman repo built from pkgbuilds (gitignored contents)
├── docs/                     # Architecture notes and design decisions
├── scripts/                  # Build/dev helper scripts
└── .github/workflows/        # CI: build (and eventually publish) the ISO
```

## Building the ISO

Building requires an Arch Linux (or Arch container) environment with
`archiso` installed — it will not run on Windows/macOS directly. See
[scripts/build.sh](scripts/build.sh) and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

```bash
sudo pacman -S --needed archiso base-devel git
git clone --recurse-submodules https://github.com/chymaera3301/Chymaera_Linux.git
cd Chymaera_Linux

# 1. Build local packages (Sarina, Calamares) as a regular user (makepkg refuses to run as root)
./scripts/build-local-packages.sh

# 2. Build the ISO as root (mkarchiso requires it)
sudo ./scripts/build.sh
```

The resulting ISO is written to `out/`.

## Status

Early scaffolding. The base archiso profile, BlackArch repo wiring, KDE
Plasma package set, and Sarina packaging exist as a starting point — expect
breakage and rapid changes.

## Sarina

[`packages/sarina`](packages/sarina) is a git submodule pointing at
[Sarina](https://github.com/chymaera3301/Sarina) (private, formerly
Chymaera Code Agent) — a local-first, Python reimplementation of the Claude
Code agent architecture, runnable against local open models. It already
ships its own Arch packaging (`packaging/arch/`) and, notably, a
[`blackarch_compat`](https://github.com/chymaera3301/Sarina/tree/main/blackarch_compat)
harness built specifically for *this* distro: it installs BlackArch's
`blackarch-*` pacman categories one at a time in disposable Docker
containers to catch install-time breakage before a category is added to
[`profile/packages.x86_64`](profile/packages.x86_64) — use it to validate the
curated BlackArch selection before treating it as final.

To pull in the latest Sarina code:

```bash
./scripts/update-sarina.sh   # advances packages/sarina, stages the pointer bump
```

## References

- [Calamares](https://codeberg.org/Calamares/calamares) — the primary
  graphical, live-session installer (AUR-only; vendored at
  `packages/pkgbuilds/calamares`). GitHub's copy is archived; Codeberg is
  where development moved.
- [archinstall](https://github.com/archlinux/archinstall) — Arch's guided
  CLI installer; kept available as a scripted alternative to Calamares.
- [archiso](https://github.com/archlinux/archiso) — the tool used to build
  this project's live/install ISO (see `profile/`).
- [archlinux/devtools](https://github.com/archlinux/devtools) — official
  clean-chroot package build/test tooling; reference point for isolating
  package builds here.
- [BlackArch](https://github.com/BlackArch/blackarch) — source of the
  security tooling repo and package catalog.
- [KDE Plasma Desktop](https://github.com/kde/plasma-desktop) — the primary
  desktop environment (installed via the `plasma-meta` group).
- [Sarina](https://github.com/chymaera3301/Sarina) — the AI agent
  integrated into the OS (private repo, submodule at `packages/sarina`).

## License

[GPL-3.0](LICENSE), matching the convention used by BlackArch and most
security-tooling distributions.
