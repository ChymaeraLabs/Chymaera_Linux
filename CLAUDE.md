# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Chymaera Linux is an Arch-based security distribution. This repo contains **no
application code** — it is an [archiso](https://github.com/archlinux/archiso)
profile plus the packaging and build glue that turns it into a bootable ISO.
The only first-party software (Sarina) lives in a separate private repo,
vendored here as a submodule.

Read `docs/ARCHITECTURE.md` before making design decisions; it records *why*
the current structure exists (a small baked-in tool core over BlackArch
category groups, Calamares over `archinstall`, etc.).

## The build cannot run on this machine

The primary development machine is Windows, but `mkarchiso` requires Arch
Linux and root. There is no way to build or smoke-test the ISO locally from
Windows — changes are validated either in WSL with an Arch distro (clone into
the ext4 side, **not** `/mnt/c`, or symlinks and permissions break) or by
pushing and reading the GitHub Actions run.

Because of that, static verification matters more than usual here. Prefer
simulating what a tool will do over assuming it works — see the
`packages.x86_64` note below for a concrete example.

## Build commands

Two stages, and the root/non-root split is mandatory, not stylistic:
`makepkg` refuses to run as root, and `mkarchiso` requires it.

```bash
# 1. Build local packages (sarina-git, calamares) into repo/x86_64/
#    MUST be a regular user.
./scripts/build-local-packages.sh

# 2. Build the ISO. MUST be root. Reads repo/x86_64/ from step 1.
sudo ./scripts/build.sh

# Advance the Sarina submodule and stage the pointer bump
./scripts/update-sarina.sh
```

`scripts/build.sh` honours `CHYMAERA_WORK_DIR` and `CHYMAERA_OUT_DIR` for
build hosts where `work/` and `out/` must sit on a different filesystem; CI
uses these to move the build off the runner's small root disk.

There is no test suite, linter, or build step for this repo itself. Sarina has
its own (`packages/sarina`, own CLAUDE.md) — do not run or modify those from
here.

## Things that will bite you

**`profile/packages.x86_64` cannot have trailing comments.** mkarchiso parses
it with `sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d'`, which strips the
comment but leaves the whitespace before it, yielding a package name with
trailing spaces that pacman cannot resolve. Put annotations on their own
lines. Verify any edit by simulating the real parser:

```bash
sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' profile/packages.x86_64 | grep -c '[[:blank:]]$'   # must be 0
```

**Pin providers explicitly.** Virtual dependencies with multiple providers
(`tessdata`, `ttf-font`, `mysql`, `oci-runtime`, …) make pacstrap print a
numbered menu and then silently take option 1, which is often absurd
(`tesseract-data-afr` for `tessdata`). New packages that introduce a provider
choice need an explicit entry in the "explicit provider choices" section.

**`profile/pacman.conf` contains a `@@CHYMAERA_REPO_DIR@@` placeholder.** It is
deliberate — `scripts/build.sh` substitutes an absolute path into a *work copy*
so the checked-in file stays portable. Do not "fix" it to a real path.

**`profile/airootfs/` contains real git symlinks (mode `120000`).** On Windows
they may materialise as plain text files. Check with `git ls-files -s` before
assuming they're broken, and never commit them as regular files.

**`profile/` is a fork of archiso's `releng` profile**, kept deliberately close
to upstream. When something is missing, copy it verbatim from
`/usr/share/archiso/configs/releng/` (or the archiso GitLab) rather than
writing it from memory — the mkinitcpio configs in
`profile/airootfs/etc/mkinitcpio.*` are exact upstream copies for this reason,
and getting their hook list subtly wrong produces an ISO that builds fine and
then panics at boot.

## CI

`.github/workflows/build-iso.yml` runs `archlinux:latest` privileged on
`ubuntu-latest`. Two constraints shape it:

- **Disk.** The runner's `/` has ~14 GB free, nowhere near enough for a
  BlackArch + Plasma pacstrap. The job mounts the runner's ~70 GB `/mnt`
  scratch disk into the container and puts the work tree, pacman cache, and
  ISO output there. When `/` or `/mnt` fills, the runner agent is killed and
  GitHub uploads **no log at all** for the job — a 22-byte empty zip. The
  build step therefore prints free space every 30s so the log tail always
  shows which filesystem ran out. Keep that watcher.
- **Private submodule.** `packages/sarina` is a private repo, so
  `actions/checkout` needs the `SARINA_REPO_TOKEN` secret (Contents: read on
  *both* repos, since it replaces the token for the whole checkout).

Diagnosing a failed run without `gh` installed: the REST API works with a PAT
carrying Actions: read. An empty log zip plus steps with `conclusion: None`
means the runner died rather than the build failing.

## Tool delivery model

The ISO ships a **small hand-picked core** of security tools, not
`blackarch-*` category groups. The groups were tried and abandoned — they
pulled in thousands of packages, unresolvable `lib32-*` deps, provider menus,
and an ISO too large for CI. `docs/ARCHITECTURE.md` has the full reasoning.

Two constraints follow from that, and both are easy to break:

- **The core must stay offline-useful.** Its whole justification is that a
  live USB works air-gapped. Do not thin it out on size grounds without
  saying what offline capability is being given up.
- **Everything past the core belongs to Sarina**, including generating
  `.desktop` entries and Plasma menu categories for newly installed tools.
  Neither capability exists yet. Do not add tools to `packages.x86_64` to
  work around that gap — it makes the eventual agent-side work harder to
  justify and quietly re-creates the problem the categories caused.

Verify any change to the package list by resolving it against live repos on
an Arch host with `[blackarch]` configured — this catches conflicts and
provider menus that CI would only surface hours later, or not at all:

```bash
mapfile -t PKGS < <(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' profile/packages.x86_64 | grep -vx -e calamares -e sarina-git)
pacman -Sp --print-format '%r/%n' "${PKGS[@]}"   # must exit 0, print no provider menu
```

Adding or removing whole tool *categories* is a product decision for the
maintainer, not a build fix to apply unilaterally — it changes what the
distro is.

## Working alongside other Claude instances

Other instances work on the sibling projects in this ecosystem — chiefly
**Sarina** (`chymaera3301/Sarina`, vendored here as `packages/sarina`). They
have repo access. This section is the coordination surface: keep it a
**contract**, not a message log. Anything that is a passing note belongs in a
commit message or the PR, not here — CLAUDE.md loads into every session, so
churn here costs every future session context.

If you change something on this list, say so in your commit message using the
word `CONTRACT:` so the other side can grep for it.

### What Chymaera consumes from Sarina

`packages/pkgbuilds/sarina-git/PKGBUILD` builds the submodule directly. It
will break if any of these move or disappear — verified present as of the
`49d6c44` submodule pointer:

| Path in the Sarina repo | Used for |
| --- | --- |
| `pyproject.toml` | `python -m build --wheel --no-isolation` |
| `packaging/arch/sarina-service.service` | installed to `/usr/lib/systemd/system/` |
| `packaging/arch/sarina.sysusers` | installed to `/usr/lib/sysusers.d/sarina.conf` |
| `packaging/arch/service.env.example` | installed to `/etc/sarina/` |
| `README.md` | installed to `/usr/share/doc/sarina-git/` |

Runtime deps declared in that PKGBUILD are `python`, `python-fastapi`,
`uvicorn`, `python-pydantic`. **These must stay in sync with Sarina's real
dependencies**, and every one must exist in Arch's repos — Arch's uvicorn
package has no `python-` prefix, which has already broken this build once.
A dependency that is PyPI-only needs a PKGBUILD of its own here first.

Entry points the ISO expects on `PATH`: `sarina`, `sarina-gui`,
`sarina-service`.

### What Chymaera needs Sarina to provide (not built yet)

The ISO deliberately ships a small tool core and defers the rest. These are
the capabilities that gap depends on — see `docs/ARCHITECTURE.md`:

1. **Install-time tool selection** — ask what the machine is for, install
   accordingly, rather than a category guess baked into the ISO.
2. **Categorisation** — generate `.desktop` entries and Plasma menu
   categories for tools that drop bare binaries into `/usr/bin`.
3. **Data analysis** — the reason the agent is in the OS at all: making sense
   of scan and capture output in place.
4. **`blackarch_compat` against a real Docker daemon** — currently
   unit-tested only. It is the safety check behind (1); until it has actually
   run, treat any category the agent proposes as unvalidated.

### Advancing the submodule

`./scripts/update-sarina.sh` moves the pointer and stages it. After bumping,
re-check the table above before committing — a green ISO build is the only
thing that proves the packaging contract still holds.
