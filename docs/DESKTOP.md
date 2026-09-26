# Desktop: one Hyprland session, two looks

Chymaera's desktop is [Omarchy](https://github.com/omacom/omarchy)-derived
Hyprland with a second look that imitates a macOS/MacTahoe desktop, switched
with **SUPER + F12** and no logout. Plasma stays installed as a real fallback
session. This document records what Omarchy actually is, what we took from it,
what we did not, and what is not verified yet.

## Status

| Piece | State |
| --- | --- |
| Hyprland session installable and selectable at the SDDM greeter | Built, **not boot-tested** |
| Two looks + `chymaera-desktop-mode` toggle | Built; script unit-tested with stubs, **never run inside Hyprland** |
| Hyprland as the autologin default | **Not done** — Plasma still autologins |
| Omarchy's Quickshell shell (real bar, menu, lock, notifications) | Not adopted; Waybar approximation instead |
| Omarchy theme system (`colors.toml` + templates) | Not built |
| MacTahoe GTK theme | Not packaged (icons, cursor, Kvantum are) |
| Proton VPN, Sarina crash diagnosis | Contracts only; see below |

Nothing here has run on a real machine: the build host is Windows. Static
checks that *were* done: the package list resolves against live Arch repos
(197 requested, no provider menus, no conflicts), every Lua file parses under
`luac`, both Waybar configs parse as JSON, and `chymaera-desktop-mode` passes
`bash -n` and a stubbed functional test (toggle both ways, no duplicated GTK
keys, garbage state file falls back to the default look).

## What Omarchy is (as of v4.0.4)

Read from the repo at tag `v4.0.4`; the latest at the time of writing.

- **Hyprland with a Lua config.** Hyprland deprecated hyprlang in 0.55 in favour
  of `hyprland.lua`; Arch's `hyprland` is 0.56.2. Omarchy's config is
  `hl.config`, `hl.bind`, `hl.dsp.*`, `hl.window_rule` calls.
- **A Quickshell desktop shell.** Bar, menu, notifications, lock screen, OSDs
  and panels are QML plugins in one long-lived Quickshell process
  (`shell/plugins/`). It is not Waybar or Walker any more, and `walker` is not
  in Arch's repos.
- **Two packages, built in a separate repo (`omarchy-pkgs`):** `omarchy`
  (binaries, themes, the shell) and `omarchy-settings` (`/etc` drop-ins,
  bootloader, snapshot and mkinitcpio config). They are tightly coupled to
  Omarchy's own installer, Limine and Snapper. Adopting them wholesale would
  replace parts of Chymaera that archiso and Calamares own, so we do not.
- **The `[omarchy]` pacman repo:** `https://pkgs.omarchy.org/stable/$arch`,
  `SigLevel = Required DatabaseOptional`, signing key
  `40DFB630FF42BCFFB047046CF0134EE680CAC571`. Channels: `stable`, `rc`, `edge`.
  Its package list is not published anywhere I could read (the directory
  listing 404s); the names are inferred from `install/omarchy-base.packages`.
- **Theming:** a theme is a `colors.toml` plus templates in `default/themed/`
  rendered into each app's config by `omarchy-theme-set`.
- **Toggles:** a toggle copies a small Lua file into
  `~/.local/state/omarchy/toggles/hypr/` and runs `hyprctl reload`. This is the
  mechanism `chymaera-desktop-mode` copies.
- **"AI":** Omarchy ships launchers for coding-agent CLIs. The feature closest
  to "AI troubleshooting a game" is **crash diagnosis**: a systemd-coredump
  watcher raises a "Process crashed" notification; clicking it hands the crash
  to the default agent along with a `diagnose-crash` skill. See below.

## Design

### One session, two looks

`~/.config/hypr/hyprland.lua` sets up everything common (environment, input,
keybindings, session services), then loads `modes/omarchy.lua` or
`modes/stealth.lua` depending on one word in
`~/.local/state/chymaera/desktop-mode`. The word is checked against a fixed
list, so the state file can never steer `dofile()` at an arbitrary path.

`chymaera-desktop-mode toggle` writes the word, runs `hyprctl reload`, then
restarts the bar and dock and rewrites GTK icon and Kvantum settings.

| | `omarchy` (default) | `stealth` |
| --- | --- | --- |
| Windows | tiled, 5px gaps, 2px gradient border | floating, no gaps, 12px rounded, shadow, blur |
| Bar | Waybar: workspaces, clock, status | Waybar: menu bar (active app left, status + clock right) |
| Dock | none | `nwg-dock-hyprland`, translucent shelf |
| GTK icons / Kvantum | Adwaita / KvAdaptaDark | MacTahoe-dark / MacTahoeDark |

Keybindings are identical in both, so nothing has to be relearned when
switching. That includes `SUPER + T` (float/tile a window), which is the manual
fix for windows that were already open when the look changed.

**Known limits.** Stealth is an imitation of macOS, not Plasma; someone who
clicks around will notice. The bar uses text labels (`wifi`, `vol`) because no
icon font is guaranteed to be present. Windows already open at the moment of the
switch may keep their old float/tile state. There is no lock screen: the live
account has no password, so a lock screen would have nothing to unlock with.

### Why Waybar and not Omarchy's Quickshell shell

Because the shell is the part that makes Omarchy feel like Omarchy, this is a
deliberate downgrade and a stopgap. Vendoring `shell/` means pinning Omarchy's
`bin/` helper scripts too — its AGENTS.md states that commands installed by the
default package set are runtime invariants and are called without presence
checks — and none of that has been evaluated against a Chymaera image. The
sensible order is: boot-test this, then decide whether to vendor the Quickshell
shell as a pinned package (like the MacTahoe PKGBUILDs), not before.

### Phasing

1. **This change.** Hyprland is installed and selectable; Plasma is still the
   autologin session.
2. **Boot-test in a VM** (or read the CI ISO). Confirm Hyprland starts, the
   bar and dock appear, and SUPER + F12 flips the look.
3. **Make Hyprland the default.** In
   `profile/airootfs/etc/sddm.conf.d/autologin.conf`, change `Session=plasma` to
   `Session=hyprland-uwsm`. `hyprland` ships `hyprland-uwsm.desktop` (checked
   against Arch's file list for the package). The live-session accommodations —
   passwordless sudo, polkit rule, no lock screen — already cover it.
4. **Decide on the Quickshell shell and the theme system** (`colors.toml` +
   templates, ported to Waybar/GTK/Kvantum).
5. **Package the MacTahoe GTK theme** so stealth mode covers GTK apps, not just
   icons and Kvantum.

## The `[omarchy]` repo

It is **not** enabled on the ISO or in the installed system yet. It is a
third-party repository whose signing key can push root-installed packages onto a
security distro, the same kind of trust decision as `[blackarch]`, made
separately. When enabled, it should be:

- opt-in, added by Sarina on request, never baked into the live image;
- pinned to the `stable` channel (`https://pkgs.omarchy.org/stable/$arch`); an
  older `https://pkgs.omarchy.org/$arch` path serves only `omarchy-keyring`,
  which is a documented pitfall;
- fetched with the key fingerprint verified against
  `40DFB630FF42BCFFB047046CF0134EE680CAC571` before `pacman-key --lsign-key`.

The packages worth pulling from it are the apps and utilities in Omarchy's
package list, not `omarchy` or `omarchy-settings` (see above).

## Sarina contracts

Neither exists yet. They are recorded in `CLAUDE.md` as things Chymaera needs
from Sarina.

### Crash diagnosis

Omarchy's design, which we should copy: a `systemd-coredump` watcher, a
notification carrying the PID/binary/signal, and a hand-off to the agent with a
skill that says how to investigate. In Chymaera the agent is Sarina. For games
the useful evidence is the coredump, the Proton/Wine log, `journalctl`, GPU
driver state, and the launch options. Sarina should propose fixes, not apply
them unattended.

### Proton VPN

Correction to an earlier claim: **`proton-vpn-gtk-app` is in Arch's official
`extra` repo** (4.18.1 when checked; 4.18.2 in `extra-testing`), not only the
AUR. Proton does not officially support Arch, but pacman now delivers updates
the normal signed way, which gives the "talk to the repo and keep updating"
behaviour without any packaging on our side. It needs NetworkManager and a
keyring (gnome-keyring or kwallet).

- **Install on demand, not baked in.** It needs an account, so it does not
  serve the offline-core rationale. Sarina installs it when asked. Only
  `wireguard-tools` is on the ISO.
- **Kill switch belongs outside Sarina.** If the VPN must fail closed, that rule
  lives in nftables (or the app's own NetworkManager kill switch), so a crashed
  or prompt-injected agent cannot leave it open. Sarina may *propose* changes to
  network config; a human approves them, and Chymaera Sentry is the natural
  watcher for that surface.
- **Adapting to updates** means Sarina reading the package's changelog and
  version delta after `pacman -Syu` and flagging what changed for the VPN
  (NetworkManager connection names, kill-switch behaviour). Known past breakage:
  Arch forum reports of connection errors after specific app versions.
- **Tailscale and Headscale are a different tool.** They build a private mesh
  between *your own* devices over WireGuard; they do not route traffic out
  through Proton. Useful for connecting a Chymaera box to a team or a Flipper
  rig, but separate from this.
- **A VPN that hides the source address can conflict with scoped engagements**
  and client allow-lists, so it should be a toggle, not always on.
