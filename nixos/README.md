# NixOS config

A flake with four outputs:

- `vm` — QEMU VM for iterating on the config from anywhere with Nix + flakes.
- `laptop` — T480 real install (Intel-only, LUKS).
- `minerva` — desktop real install: Intel Arrow Lake (Core Ultra 7 265K) + a
  **Blackwell NVIDIA dGPU**, all AI tooling (`modules/ai.nix`). LUKS at its
  (pending) reinstall. `hosts/minerva/hardware.nix` carries the current
  Pop!_OS UUIDs as a placeholder until then.
- `minerva-live` — live-USB ISO of the minerva system for a no-disk test drive.

## How dotfiles work here

Home Manager symlinks `~/.config/<app>` → `~/code/tomfordweb/dotfiles/config/<app>`
(`home/dotfiles.nix`, via `mkOutOfStoreSymlink`). Edits to repo files are
**live** — no rebuild; `hyprctl reload` / app restart is enough. Adding a
NEW app to the managed set does need a rebuild (and a matching entry in
`install/bootstrap.sh` for non-nix hosts).

Two contracts:

- The repo must live at `~/code/tomfordweb/dotfiles` (absolute path baked
  into the symlinks).
- Machine-local Hyprland overrides go in `~/.config/hypr-local/*.conf` —
  NOT inside `~/.config/hypr`, which is the repo symlink.

## Repo layout / module map

```
nixos/
├── flake.nix               # inputs + mkHost helper + the four outputs
├── flake.lock              # pinned input revs (commit after `nix flake update`)
├── hosts/                  # one dir per machine
│   ├── vm/                 #   default.nix (imports) + hardware.nix (qemu)
│   ├── t480/               #   default.nix (VA-API, imports luks/laptop) + hardware.nix (generated)
│   ├── minerva/            #   default.nix (zram, storage/smb mounts, steam, backup timers) + hardware.nix (placeholder)
│   └── minerva-live/       #   ISO wrapper (installer profile + nvidia)
├── modules/                # system-level, shared
│   ├── core.nix            #   users, network, audio, ssh, docker, 1password, zsh, flatpak, VM variant
│   ├── hyprland.nix        #   Hyprland, SDDM + hm session wrapper, portals, fonts, wayland utils
│   ├── laptop.nix          #   brightnessctl, upower, power-profiles-daemon (t480 only)
│   ├── ai.nix              #   ollama-cuda + beads (minerva only)
│   ├── nvidia.nix          #   Blackwell open module, driver ≥570, wayland env (minerva only)
│   ├── luks.nix            #   cryptroot preLVM/TRIM tuning (device UUID comes from hardware.nix)
│   ├── tor.nix             #   tor daemon (SOCKS5 :9050) + torsocks (all hosts)
│   └── code-drive.nix      #   ~/code btrfs drive + hourly btrbk snapshots (minerva only)
└── home/                   # Home Manager (user tom)
    ├── default.nix         #   entry point — imports the dev core below
    ├── dotfiles.nix        #   ~/.config symlinks into the repo + PATH + EDITOR
    ├── shell.nix           #   zsh + oh-my-zsh + starship + direnv
    ├── dev.nix             #   ghostty, rg/fd/jq/bat/fzf, lazygit/gh/glab, node/rust/python
    ├── neovim.nix          #   nvim wrapped with ALL runtime deps (LSPs, formatters, tree-sitter)
    ├── tmux.nix            #   tmux + tpm clone on activation
    └── gui-apps.nix        #   firefox, spotify, discord, dbeaver, ... (per-host via homeModules)
```

### Where does a setting live?

| You want to change… | Edit |
| --- | --- |
| a keybind, monitor layout, waybar module | `config/` in the repo root (live, no rebuild) |
| a CLI/dev tool for all machines | `home/dev.nix` |
| an nvim LSP/formatter dependency | `home/neovim.nix` (and `config/nvim/lua/plugins/lsp.lua`) |
| a GUI app | `home/gui-apps.nix` |
| a system service / daemon | `modules/core.nix` (all hosts) or the host's `hosts/<h>/default.nix` |
| something desktop-AI (ollama, beads) | `modules/ai.nix` |
| something laptop-only | `modules/laptop.nix` |
| per-host disks/mounts that survive reinstall | `hosts/<h>/default.nix` (hardware.nix gets clobbered) |

## Prerequisites

- Nix with flakes enabled.
- All files under `nixos/` staged in git (`git add nixos/`) — Nix flakes only
  see git-tracked files. Staging is enough; no commit needed.

## Building the VM

```bash
cd nixos
git add -A .                                              # make nix see uncommitted files
nix build .#nixosConfigurations.vm.config.system.build.vm
./result/bin/run-nixos-vm-vm                              # launches QEMU
```

Default login: `tom` / `nixos`. Password auth is enabled for SSH inside the
VM. Sudo is passwordless in the VM only.

The host's `~/code/tomfordweb/dotfiles` is mounted read-write into the guest
at the same path via 9p, so the `~/.config` symlinks resolve and changes to
`config/hypr/*.conf` etc. are live — just `hyprctl reload` inside the VM.
The VM's mod key is ALT (tmpfiles drops `~/.config/hypr-local/qemu-mainmod.conf`).

VM disk state is **ephemeral** by default: each launch starts clean.

## Live-USB test drive (minerva, no disk touched)

```bash
cd nixos && git add -A .
nix build .#nixosConfigurations.minerva-live.config.system.build.isoImage
lsblk    # find the USB stick — 16 GB+ recommended
sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Boot it (F-key boot menu), log in at SDDM as `tom` / `nixos` (live-only
password). Verify: SDDM comes up (open NVIDIA module drives Blackwell),
all monitors light, Hyprland launches without a black screen.

The live session has no dotfiles repo, so Hyprland starts with defaults. For
the full test, clone the repo inside the live session (branch must be pushed):

```bash
mkdir -p ~/code/tomfordweb
git clone https://github.com/tomfordweb/dotfiles ~/code/tomfordweb/dotfiles
hyprctl dispatch exit   # back to SDDM, log in again
```

## Installing on real hardware

Full walkthrough for a fresh install. Layout: GPT with an EFI system
partition plus one big LUKS partition, btrfs inside with `@` / `@home` /
`@nix` / `@log` subvolumes, no swap partition (zram on minerva).

Drive names below are placeholders — always confirm with `lsblk` first:

- `$USB` — the installer USB stick (e.g. `/dev/sdb`)
- `$DISK` — the internal target disk (e.g. `/dev/nvme0n1`)
- NVMe partition suffix is `p1`/`p2` (`${DISK}p1`); SATA is plain numbers.

### 1. Download the installer ISO

The flake tracks `nixos-unstable`, so match with the unstable minimal ISO:

```bash
cd ~/Downloads
curl -LO https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso
curl -LO https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso.sha256
```

The `.sha256` references the versioned ISO name, so compare hashes directly:

```bash
EXPECT=$(awk '{print $1}' latest-nixos-minimal-x86_64-linux.iso.sha256)
ACTUAL=$(sha256sum latest-nixos-minimal-x86_64-linux.iso | awk '{print $1}')
[ "$EXPECT" = "$ACTUAL" ] && echo OK || echo MISMATCH
```

### 2. Flash the USB

**Danger: `dd` silently wipes whichever disk you point it at.**

```bash
lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINTS
USB=/dev/sdX          # <-- YOUR USB stick

sudo umount ${USB}?* 2>/dev/null
sudo dd if=~/Downloads/latest-nixos-minimal-x86_64-linux.iso \
        of=$USB bs=4M status=progress conv=fsync oflag=direct
sync
```

### 3. Boot the installer

Boot menu (F12 on the ThinkPad), pick the USB, default entry, land at a
shell as `nixos@nixos`, then `sudo -i`.

**Network.** Ethernet auto-connects. Wi-Fi on the minimal ISO:

```bash
wpa_passphrase MYSSID 'MYPASSWORD' > /etc/wpa_supplicant.conf
systemctl restart wpa_supplicant
```

Confirm: `ping -c 2 cache.nixos.org`.

### 4. Partition + install

**Point of no return — everything on `$DISK` is destroyed.** On minerva:
reformat ONLY the root disk — do NOT touch `nvme1n1` (btrfs label `code`),
`sda` (btrfs label `storage`), or a preserved `/home` partition if you're
keeping one.

```bash
DISK=/dev/nvme0n1     # <-- YOUR internal disk (lsblk to confirm)
wipefs -a $DISK
parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MiB 1GiB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart cryptroot 1GiB 100%
```

**LUKS** (both t480 and minerva). The mapper name **must** be `cryptroot`;
`modules/luks.nix` and the generated hardware config reference
`/dev/mapper/cryptroot`. The passphrase is typed every boot.

```bash
cryptsetup luksFormat ${DISK}p2
cryptsetup open ${DISK}p2 cryptroot
```

**Filesystems + subvolumes:**

```bash
mkfs.fat -F 32 -n boot ${DISK}p1
mkfs.btrfs -L nixos /dev/mapper/cryptroot

mount -t btrfs /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
umount /mnt

OPTS='compress=zstd:1,noatime,ssd,discard=async'
mount -o subvol=@,$OPTS      /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,var/log,boot}
mount -o subvol=@home,$OPTS  /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,$OPTS   /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,$OPTS   /dev/mapper/cryptroot /mnt/var/log
mount ${DISK}p1 /mnt/boot
```

**Generate hardware config + pull the flake:**

```bash
nixos-generate-config --root /mnt

nix-shell -p git --run '
  mkdir -p /mnt/home/tom/code/tomfordweb
  git clone https://github.com/tomfordweb/dotfiles \
    /mnt/home/tom/code/tomfordweb/dotfiles
'
```

**Replace the host's hardware.nix with the generated one:**

```bash
# t480:
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/tom/code/tomfordweb/dotfiles/nixos/hosts/t480/hardware.nix
# minerva:
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/tom/code/tomfordweb/dotfiles/nixos/hosts/minerva/hardware.nix
```

**minerva only:** uncomment the `../../modules/luks.nix` import in
`nixos/hosts/minerva/default.nix` (it's gated because the module fails eval
without a cryptroot device — which now exists).

**LUKS UUID sanity check** — `nixos-generate-config` detects the LUKS device
and writes it into the copied hardware config; nothing to edit by hand:

```bash
grep -A1 luks /mnt/home/tom/code/tomfordweb/dotfiles/nixos/hosts/*/hardware.nix
```

It should show `boot.initrd.luks.devices."cryptroot".device` with the UUID
of the raw LUKS partition (`blkid -s UUID -o value ${DISK}p2` to compare).

Stage the changes (flakes only see git-tracked files; no commit needed):

```bash
cd /mnt/home/tom/code/tomfordweb/dotfiles
git add nixos/
```

**Install:**

```bash
nixos-install --flake /mnt/home/tom/code/tomfordweb/dotfiles/nixos#t480   # or #minerva
```

Sets a root password near the end. Then fix ownership of the root-made
clone and reboot:

```bash
chown -R 1000:100 /mnt/home/tom
reboot
```

### 5. First boot

LUKS passphrase prompt, then SDDM. **`tom` has NO password on a real
install** — switch to a TTY (Ctrl+Alt+F2), log in as root, and:

```bash
passwd tom
```

**minerva only — do BOTH of these on this TTY, before the first SDDM login:**

1. Migrate the preserved Pop!_OS home (same uid 1000):
   ```bash
   mv /home/tomford /home/tom
   chown tom:users /home/tom
   ```
   Log in first by accident and home-manager scaffolds a fresh `/home/tom`
   you'll have to merge. After migration everything survives in place:
   `~/.ssh`, `~/.local/bin/workmux`, `~/.claude`, `~/.tmux`,
   `~/Documents/Wallpaper-Bank`. `~/code` is the separate btrfs drive,
   mounted by label regardless.
2. Move aside pre-existing real config dirs that would block home-manager's
   symlink activation (it refuses to clobber real files):
   ```bash
   cd /home/tom/.config
   for d in hypr ghostty gh glab-cli git tmux nvim lazygit waybar wofi starship.toml workmux thefuck; do
     [ -e "$d" ] && [ ! -L "$d" ] && mv "$d" "$d.pre-nixos"
   done
   ```
   (Merge anything you care about — e.g. `gh.pre-nixos/hosts.yml` auth —
   back by hand afterward.)

Back at SDDM (Ctrl+Alt+F1), log in as `tom`; the default session is
Hyprland with the home-manager env wrapper. Then:

```bash
cd ~/code/tomfordweb/dotfiles
git submodule update --init                      # neovim, waybar nvidia, wiki
sudo nixos-rebuild switch --flake ./nixos#t480 # or #minerva
```

Post-install one-timers:

- WiFi: `nmcli device wifi connect "SSID" --ask`.
- Flathub remote (flatpak is enabled but has no remotes declared):
  ```bash
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  ```
- SSH: key-only on real installs — drop a key in `~/.ssh/authorized_keys`
  from the console before relying on remote access.
- Tailscale: `sudo tailscale up`.

### 6. Post-hop checklist (minerva)

Once booted with `~/code` mounted:

```bash
# user-space AI tooling (Claude/opencode/codex symlinks, MCP servers)
cd ~/code/tomfordweb/ops && ansible-playbook local.ai.yml

# beads + ollama come from nix (modules/ai.nix) — verify:
bd version && systemctl status ollama

# nvim deps (LSPs, formatters, tree-sitter) come from nix — verify inside nvim:
#   :checkhealth  and  which tree-sitter / prettierd from :!which

# tmux plugins (tpm is cloned by home-manager activation)
#   inside tmux: <C-a I>

# workmux survives on the preserved /home — verify + rewire hooks/skills
workmux --version && workmux setup

# Tor: daemon should be up; browser is in the app launcher
systemctl status tor
torsocks curl -s https://check.torproject.org/api/ip   # expect "IsTor":true

# SMB share credentials (hosts/minerva mounts /mnt/dubious-smb on demand)
sudo mkdir -p /etc/nixos-secrets
printf 'username=dubious\npassword=%s\n' \
  "$(op read 'op://tomfordweb/Dubious Samba/password')" \
  | sudo tee /etc/nixos-secrets/dubious-smb >/dev/null
sudo chmod 600 /etc/nixos-secrets/dubious-smb

# monitors: verify the layout names still match
hyprctl monitors   # fix config/hypr/configs/minerva.conf if renumbered
```

Known ops-repo follow-ups (fix in `~/code/tomfordweb/ops`, not here):

- `vars/local-variables.yml` `playwright_chrome_path` points at the Pop!_OS
  build — re-run `npx playwright install chromium` and repoint.
- `templates/dbeaver-droplet-tunnel.service.j2` hardcodes `/usr/bin/ssh` —
  change to plain `ssh`.
- fnm node paths baked into `claude.tomfordweb/settings.json` / `.mcp.json`
  need the nix node path.
- `local.code-drive.yml`, `local.smb_mount.yml`, `local.backup-strategy.yml`,
  `local.ollama.yml` are superseded by `modules/code-drive.nix`,
  `hosts/minerva` (smb + backup timers), and `modules/ai.nix` — don't run them.

## Day-to-day administration

All commands run from a checkout of this repo.

### Applying config changes

```bash
sudo nixos-rebuild switch --flake ~/code/tomfordweb/dotfiles/nixos#minerva   # or #t480
```

Atomic: builds the new closure, activates, adds a bootloader entry. On
failure the previous generation is untouched. Home Manager is wired in as a
NixOS module, so this also applies the `home/` config — no separate
`home-manager switch`.

| command | effect |
| --- | --- |
| `nixos-rebuild switch` | build, activate now, add to boot menu |
| `nixos-rebuild test`   | build, activate now, **don't** add to boot menu |
| `nixos-rebuild boot`   | build, add to boot menu, apply on next reboot |
| `nixos-rebuild build`  | build only, don't activate |
| `nixos-rebuild dry-activate` | print what would change |

Remember: **dotfile edits (`config/`) need no rebuild** — only changes under
`nixos/` do. New files must be `git add`ed before nix sees them.

### Rolling back

```bash
sudo nixos-rebuild switch --rollback         # from a running system
```

Or pick a previous generation in the systemd-boot menu at boot.

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
sudo nix-collect-garbage --delete-older-than 14d
sudo nixos-rebuild boot                      # regenerate boot entries after GC
```

### Updating packages

```bash
nix flake update                             # all inputs (nixpkgs, home-manager, hyprland)
nix flake update nixpkgs                     # or one at a time
sudo nixos-rebuild switch --flake .#minerva
```

Commit `flake.lock` afterward. The hyprland input follows nixpkgs (single
nixpkgs eval); if a bump ever forces long source builds of Hyprland, the
fallback is dropping the input and using nixpkgs' `pkgs.hyprland`.

### Searching packages / options (offline-friendly)

```bash
nix search nixpkgs firefox
man configuration.nix                        # NixOS options manual (installed)
man home-configuration.nix                   # Home Manager options manual (installed)
nixos-option services.ollama.enable          # current value + docs for one option
```

Web (when online): <https://search.nixos.org/packages>, <https://search.nixos.org/options>.

### minerva — NVIDIA Blackwell notes

`modules/nvidia.nix` (minerva + minerva-live only):

- **`hardware.nvidia.open = true` is MANDATORY.** Blackwell has no
  closed-source kernel module. `false` = black screen — opposite of old cards.
- **Driver must be ≥ 570**; module pins `nvidiaPackages.beta` and
  `linuxPackages_6_12` (new enough for Arrow Lake, old enough that the
  NVIDIA module still compiles).
- Wayland/NVIDIA env vars (`GBM_BACKEND`, …) are enabled — a pure-dGPU
  desktop commonly black-screens without them. If the compositor fails:
  Ctrl+Alt+F2 to a TTY and roll back.

### `~/code` btrfs drive + hourly btrbk snapshots

Declared in `modules/code-drive.nix`, imported by `minerva` only (the T480
and VM have none). The drive is found by btrfs label `code`, not device name.

One-time bootstrap on a new machine: `sudo mkfs.btrfs -L code /dev/nvmeXnY`
(confirm with `lsblk`!), then rebuild. First boot mounts the fs top at
`/mnt/code-btr`, creates `@code`/`@snapshots` subvols, mounts `@code` at
`~/code`, and enables the hourly `btrbk-code.timer`.

Retention: `24h 14d 8w`. Ops:

```bash
btrbk -c /etc/btrbk/btrbk.conf list snapshots
sudo systemctl status btrbk-code.timer
journalctl -u btrbk-code.service -n 50
```

Missing drive is safe: all mounts are `nofail`.

## Troubleshooting

- **`Path 'nixos/...' is not tracked by Git`** — `git add nixos/` (staging
  is enough).
- **`attribute 'foo' missing`** — package renamed in nixpkgs; check
  search.nixos.org.
- **Home Manager activation fails with "existing file in the way"** — a
  real file/dir sits where a symlink should go. Move it aside
  (`mv ~/.config/<app> ~/.config/<app>.bak`) and rebuild.
- **App ignores config edits** — check the symlink:
  `ls -l ~/.config/<app>` must point into the repo. Audit all of them:
  `ls -la ~/.config | grep dotfiles`.
- **Hyprland config is default in the VM** — the 9p share failed; check
  `dmesg` in the guest and that the host path exists.
- **SDDM session env missing PATH/EDITOR** — you picked the plain
  "Hyprland" session; use the default `hyprland-hm` (the wrapper sources
  hm-session-vars.sh).
- **What changed between two builds?**
  `nix store diff-closures /run/current-system ./result`.
- **Group membership changes don't take effect** — log out and back in.
