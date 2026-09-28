# Velocity Linux

Arch-based. Yours from the first boot.

Velocity is a rolling Linux distribution built on Arch Linux. It keeps Arch's
minimal base, pacman and the AUR, and adds the one thing Arch leaves out: a
built-in way to shape the system without hunting for tools.

- **Nothing installed you didn't ask for.** The base is `base` + kernel +
  NetworkManager + `velocity-tools`. Desktops, apps and themes are choices, not
  defaults.
- **`velocity`, the customizer, ships on the ISO and on every install.** Switch
  desktops, add app bundles, flip Night/Day theme, change shell, slim the
  system, take a btrfs snapshot. One command, no extra downloads.
- **A guided installer** (`velocity-install`) that asks about disk, encryption,
  user, desktop, apps and theme, then does the whole thing in one pass.
- **Looks like one product.** Violet/cyan branding across the boot menu, GRUB,
  login, shell prompt, fastfetch and wallpapers. `ID_LIKE=arch` stays, so
  everything that works on Arch works here.

## Try it

```
# download or build velocity-YYYY.MM.DD-x86_64.iso, then boot it in a VM or from USB
velocity-install          # guided install
velocity                  # explore the customizer live
velocity doctor           # hardware / network check
```

## Build the ISO

Building needs an Arch Linux environment. Docker gives you one on any OS.

| Host | Command |
|---|---|
| Linux / macOS with Docker or Podman | `./build.sh` |
| Windows with Docker Desktop (WSL2 backend) | `.\build.ps1` |
| An actual Arch box | `sudo scripts/build-iso.sh` |
| GitHub | push a `v*` tag, or run the workflow manually |

Output: `out/velocity-<date>-x86_64.iso` and `out/SHA256SUMS`. First build
downloads a few hundred MB of packages; a named Docker volume caches them.

Before building, `bash scripts/check.sh` validates every script and preset.

## What the customizer can do

```
velocity desktop list                 plasma  hyprland  gnome  xfce  core
velocity desktop set hyprland         switch desktop (previous DM disabled, theme reapplied)
velocity bundle list                  dev gaming creative office nvidia media flatpak virtualization laptop
velocity bundle add dev gaming
velocity bundle remove gaming
velocity theme set day                Night (dark, default) or Day (light)
velocity shell set fish               zsh / fish / bash with the Velocity prompt
velocity slim                         remove orphans, trim caches and journal
velocity snapshot before-nvidia       read-only btrfs snapshot of /
velocity status                       what is applied
velocity                              interactive menu (uses gum)
```

Every destructive-ish action takes a btrfs snapshot first when `/` is btrfs,
which the installer sets up by default.

## Add your own preset

A preset is a small bash file. Drop it in
`velocity-tools/presets/{desktops,bundles,themes}/<id>.preset`:

```bash
NAME="Sway"
DESC="Tiling Wayland compositor, i3-compatible."
KIND="desktop"
PACKAGES=(sway swaybg swaylock waybar foot wofi greetd greetd-tuigreet)
OPTIONAL=(mako grim slurp)
SERVICES=(greetd)
CONFLICTS=(sddm gdm lightdm)
post_apply() { :; }   # optional; runs with target_path/in_target helpers available
```

`scripts/check.sh` validates it; the next ISO build ships it.

## Repository layout

```
profile/            archiso profile (boot menus, live root overlay, package list)
velocity-tools/     the package: velocity, velocity-install, libs, presets, configs
  presets/          desktops/ bundles/ themes/
  share/configs/    Hyprland rice (hypr, waybar, kitty, rofi, dunst) with Night/Day variants
assets/generate.py  draws wallpapers, boot splash, GRUB theme pieces (no binaries in git)
scripts/            build-iso.sh (runs in Arch), check.sh (runs anywhere)
docs/               installer internals, unattended installs, design notes
```

## Design choices

- **btrfs + zstd, subvolumes `@ @home @snapshots @log @pkg`, zram swap.**
  Snapshots are the safety net that makes "just try Hyprland" cheap.
- **GRUB on the installed system, systemd-boot/syslinux on the ISO.** GRUB
  handles LUKS and os-prober for dual boot; the ISO uses what archiso does.
- **Presets are bash, not YAML.** They need to run commands in a chroot; a
  sourceable file with arrays and one optional function is the smallest thing
  that works and is easy to read.
- **`velocity-tools` is one package in a local repo baked into the ISO.**
  Nothing phones home; the installer pulls it from `/opt/velocity-repo` on the
  live medium. A hosted repo can be added later without changing the tooling.

## Status

Scaffold. Everything here is wired end to end and lint-clean, but the ISO has
not yet been booted. First milestones:

1. Build the ISO and boot it in QEMU / VirtualBox.
2. Run `velocity-install` against a virtual disk (UEFI and BIOS, with and without LUKS).
3. Boot the result, run `velocity desktop set` for each desktop.

## License

MIT. Arch Linux and the packages Velocity installs keep their own licenses.
