# Chymaera Linux

Chymaera Linux is an Arch-based distribution built for security research and
penetration testing, combining:

- **[Arch Linux](https://archlinux.org/)** as the rolling-release base
- **[BlackArch](https://github.com/BlackArch/blackarch)** tooling, available as
  a repo but not bulk-installed: the ISO ships a small offline-usable core and
  Sarina installs the rest on demand
- **[KDE Plasma](https://github.com/kde/plasma-desktop)** as the primary desktop
  environment
- **[Sarina](https://github.com/chymaera3301/Sarina)**, an AI agent integrated
  directly into the OS — for choosing and organising tooling, and for making
  sense of scan and capture output in place

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
deliberately small default tool set, a polished KDE Plasma desktop, and an
AI agent built in to help with recon, scripting, analysis, and general system
tasks.

## How tooling is delivered

The ISO ships **~27 hand-picked security tools**, not BlackArch's category
groups. Baking in the categories was tried and abandoned: it pulled in
several thousand packages nobody had chosen, along with unresolvable
32-bit dependencies and provider conflicts that made the ISO too large to
build in CI. The reasoning is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

What ships covers recon, traffic capture, wireless, password attacks, web
application testing, exploitation, reverse engineering and forensics — chosen
so that **the live session is useful with no network at all.** Air-gapped
client sites and offline forensics are where a live USB earns its keep, and
they are the one thing an install-on-demand model cannot serve.

Everything past that core is Sarina's job: asking what the machine is for,
installing accordingly, and generating the `.desktop` entries and Plasma menu
categories that BlackArch packages don't ship. Those capabilities are still
being built.

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
│       ├── sarina-git/        # PKGBUILD building packages/sarina locally
│       └── calamares/         # vendored AUR PKGBUILD (graphical installer)
├── repo/                     # local pacman repo built from pkgbuilds (gitignored contents)
├── docs/                     # Architecture notes and design decisions
├── scripts/                  # Build/dev helper scripts
├── CLAUDE.md                 # Guidance for AI agents working in this repo
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

The resulting ISO is written to `out/`. Set `CHYMAERA_WORK_DIR` and
`CHYMAERA_OUT_DIR` to put the build tree and output on a different filesystem
(CI uses this to reach a larger disk).

### Building and testing under WSL

Development happens on Windows, so WSL2 with an Arch distribution is the
normal way to build and boot-test. Two things matter:

- **Clone into the WSL filesystem** (`~/`), never `/mnt/c`. Windows drives
  don't preserve the symlinks in `profile/airootfs/` or Unix permissions, and
  a build tree there would also try to sync to OneDrive.
- **`makepkg` refuses to run as root**, so create an ordinary user for stage 1
  even though WSL logs you in as root by default.

## Status

Early, but building. The archiso profile, BlackArch repo wiring, KDE Plasma
package set, Calamares packaging and Sarina packaging are in place, and the
package set resolves cleanly (837 packages, no conflicts). Not yet done: the
agent-assisted install flow, tool categorisation, Chymaera branding, and any
Calamares configuration beyond upstream defaults. Expect rapid changes.

## Sarina

[`packages/sarina`](packages/sarina) is a git submodule pointing at
[Sarina](https://github.com/chymaera3301/Sarina) (private, formerly
Chymaera Code Agent) — a local-first, Python reimplementation of the Claude
Code agent architecture, runnable against local open models. It already
ships its own Arch packaging (`packaging/arch/`) and a
[`blackarch_compat`](https://github.com/chymaera3301/Sarina/tree/main/blackarch_compat)
harness built specifically for *this* distro: it installs BlackArch's
`blackarch-*` pacman categories one at a time in disposable Docker containers
to catch install-time breakage. Now that the ISO no longer bakes in those
categories, that harness becomes the safety check behind Sarina's own
install-time suggestions — it should know a category installs cleanly before
offering it.

Sarina's intended role in the running system, none of which exists yet:

- **Guided install** — ask what the machine is for and install tooling to
  match, instead of shipping a guess.
- **Organisation** — generate `.desktop` entries and Plasma menu categories
  for tools that drop bare binaries into `/usr/bin`, which is the problem
  Kali's curated menus solve by hand.
- **Analysis** — read scan, capture and log output in place and summarise it,
  so triage doesn't mean scrolling raw tool output.
- **Maintenance** — evaluate `pacman -Syu` and BlackArch updates for what is
  safe to apply automatically versus what needs a human look.

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
