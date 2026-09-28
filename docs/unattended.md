# Unattended installs

`velocity-install --config FILE` reads a bash file of `V_*` variables and skips
every question it can answer from it. Anything missing is still asked.

```bash
# velocity.conf
V_DISK=/dev/vda
V_DISK_MODE=wipe            # wipe | manual (then set V_ROOT_PART, V_EFI_PART)
V_ENCRYPT=no                # yes -> also set V_LUKS_PASS
V_HOSTNAME=speedy
V_USER=alex
V_USER_PASS='change-me'
V_ROOT_PASS=''              # empty = root login disabled
V_TIMEZONE=Europe/Berlin
V_LOCALE=en_US.UTF-8
V_KEYMAP=us
V_KERNEL=linux              # linux | linux-lts | linux-zen
V_DESKTOP=hyprland
V_DESKTOP_WITH=wlogout,swappy
V_BUNDLES="dev flatpak"
V_THEME=night
V_SHELL=zsh
```

```
velocity-install --config velocity.conf
velocity-install --config velocity.conf --dry-run   # prints the plan only
```

Passwords in the file are plain text. Keep the file on the live medium only and
delete it afterwards, or leave `V_USER_PASS` empty to be prompted.

## Testing in QEMU

```
qemu-img create -f qcow2 velocity.qcow2 40G
qemu-system-x86_64 -enable-kvm -m 4G -smp 4 \
  -drive file=velocity.qcow2,if=virtio \
  -cdrom out/velocity-*.iso -boot d \
  -bios /usr/share/edk2/x64/OVMF.4m.fd      # omit for BIOS test
```
