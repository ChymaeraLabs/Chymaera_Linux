# Chymaera Linux

Chymaera Linux is an Arch-based distribution built for security research and
penetration testing, combining:

- **[Arch Linux](https://archlinux.org/)** as the rolling-release base
- **[BlackArch](https://github.com/BlackArch/blackarch)** tooling, curated rather
  than fully mirrored, to keep the system stable instead of shipping every
  package in the BlackArch repo
- **[KDE Plasma](https://github.com/kde/plasma-desktop)** as the primary desktop
  environment
- **[Chymaera Code Agent](https://github.com/chymaera3301/Chymaera_Code_Agent)**,
  an AI coding/ops agent integrated directly into the OS

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
│   ├── agent/                # git submodule: Chymaera_Code_Agent source (private repo)
│   └── pkgbuilds/
│       └── chymaera-code-agent-git/  # PKGBUILD building packages/agent locally
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

# 1. Build the agent package as a regular user (makepkg refuses to run as root)
./scripts/build-agent-package.sh

# 2. Build the ISO as root (mkarchiso requires it)
sudo ./scripts/build.sh
```

The resulting ISO is written to `out/`.

## Status

Early scaffolding. The base archiso profile, BlackArch repo wiring, KDE
Plasma package set, and Chymaera Code Agent packaging exist as a starting
point — expect breakage and rapid changes.

## The Chymaera Code Agent

[`packages/agent`](packages/agent) is a git submodule pointing at
[Chymaera_Code_Agent](https://github.com/chymaera3301/Chymaera_Code_Agent)
(private) — a local-first, Python reimplementation of the Claude Code agent
architecture, runnable against local open models. It already ships its own
Arch packaging (`packaging/arch/`) and, notably, a
[`blackarch_compat`](https://github.com/chymaera3301/Chymaera_Code_Agent/tree/main/blackarch_compat)
harness built specifically for *this* distro: it installs BlackArch's
`blackarch-*` pacman categories one at a time in disposable Docker
containers to catch install-time breakage before a category is added to
[`profile/packages.x86_64`](profile/packages.x86_64) — use it to validate the
curated BlackArch selection before treating it as final.

To pull in the latest agent code:

```bash
./scripts/update-agent.sh   # advances packages/agent, stages the pointer bump
```

## References

- [archinstall](https://github.com/archlinux/archinstall) — Arch's guided
  installer; a longer-term option for a Chymaera-branded install experience.
- [archiso](https://github.com/archlinux/archiso) — the tool used to build
  this project's live/install ISO (see `profile/`).
- [archlinux/devtools](https://github.com/archlinux/devtools) — official
  clean-chroot package build/test tooling; reference point for isolating
  package builds here.
- [BlackArch](https://github.com/BlackArch/blackarch) — source of the
  security tooling repo and package catalog.
- [KDE Plasma Desktop](https://github.com/kde/plasma-desktop) — the primary
  desktop environment (installed via the `plasma-meta` group).
- [Chymaera Code Agent](https://github.com/chymaera3301/Chymaera_Code_Agent) —
  the AI agent integrated into the OS (private repo, submodule at
  `packages/agent`).

## License

[GPL-3.0](LICENSE), matching the convention used by BlackArch and most
security-tooling distributions.
