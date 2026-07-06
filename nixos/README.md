# NixOS config

A flake with two outputs:

- `vm` — QEMU VM for iterating on the config from Arch (or anywhere with Nix + flakes).
- `laptop` — real install target. `hardware-laptop.nix` is a placeholder until first install.

The user's dotfiles at `~/code/tomfordweb/dotfiles` are used as `$XDG_CONFIG_HOME` (via `home.nix`), so Hyprland/Waybar/Wofi read the same configs on NixOS as on Arch.

## Prerequisites

- Nix with flakes enabled. On Arch this box uses Determinate Nix — flakes are on by default.
- All files under `nixos/` staged in git (`git add nixos/`) — Nix flakes only see git-tracked files. You do **not** need to commit; staging is enough.

## Building the VM

```bash
cd nixos
git add -A .                                              # make nix see uncommitted files
nix build .#nixosConfigurations.vm.config.system.build.vm
./result/bin/run-nixos-vm-vm                              # launches QEMU
```

Default login: `tom` / `nixos`. Password auth is enabled for SSH inside the VM. Sudo is passwordless in the VM only.

The host's `~/code/tomfordweb/dotfiles` is mounted read-write into the guest at the same path via 9p (`virtualisation.sharedDirectories`). Changes to `config/hypr/*.conf` etc. are live — no rebuild needed; just `hyprctl reload` inside the VM.

VM disk state is **ephemeral** by default: each launch starts clean. If you want persistence, set `virtualisation.diskImage = "./nixos.qcow2";` under `virtualisation.vmVariant` in `hardware-vm.nix`.

## Installing on real hardware (laptop)

1. Boot the NixOS installer ISO.
2. Partition + format (LUKS + LVM or btrfs subvols — your call). Mount root at `/mnt`.
3. `nixos-generate-config --root /mnt` — produces `/mnt/etc/nixos/hardware-configuration.nix` with real UUIDs and kernel modules.
4. Copy that file over `hardware-laptop.nix` in this repo (keep the filename).
5. Update the LUKS UUID in `luks.nix` to match the real encrypted volume.
6. Clone the dotfiles to `/mnt/home/tom/code/tomfordweb/dotfiles` so the flake path is where the config expects it.
7. `nixos-install --flake /mnt/home/tom/code/tomfordweb/dotfiles/nixos#laptop`.
8. Reboot, log in on TTY, `passwd` to set a real password, then remove `initialPassword` from `configuration.nix` and rebuild.

## Day-to-day administration

All commands run from a checkout of this repo (any path — flake refs are absolute).

### Applying config changes

```bash
sudo nixos-rebuild switch --flake .#laptop
```

Atomic: builds the new system closure, activates it, and adds a bootloader entry. On failure, the previous generation is untouched.

Variants:

| command | effect |
| --- | --- |
| `nixos-rebuild switch` | build, activate now, add to boot menu |
| `nixos-rebuild test`   | build, activate now, **don't** add to boot menu (good for experiments) |
| `nixos-rebuild boot`   | build, add to boot menu, apply on next reboot |
| `nixos-rebuild build`  | build only, don't activate |
| `nixos-rebuild dry-activate` | print what would change |

### Rolling back

Something broke after `switch`? Two ways:

```bash
sudo nixos-rebuild switch --rollback         # from a running system
```

Or from the systemd-boot menu at boot: pick a previous generation.

List generations:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Delete old generations to reclaim space:

```bash
sudo nix-collect-garbage --delete-older-than 14d
sudo nixos-rebuild boot                      # regenerate boot entries after GC
```

### Updating packages

The flake pins nixpkgs, home-manager, and hyprland. Bump them with:

```bash
nix flake update                             # updates all inputs
nix flake update nixpkgs                     # or one at a time
sudo nixos-rebuild switch --flake .#laptop
```

Commit `flake.lock` afterward so the pin is reproducible.

### User environment (Home Manager)

Home Manager is wired in as a NixOS module, so `nixos-rebuild switch` also applies the `home.nix` config for `tom`. No separate `home-manager switch` needed.

### Searching for packages / options

```bash
nix search nixpkgs firefox
man configuration.nix                        # NixOS options manual
man home-configuration.nix                   # Home Manager options manual
```

Or the web: <https://search.nixos.org/packages> and <https://search.nixos.org/options>.

### Docker

`virtualisation.docker.enable = true` and `tom` is in the `docker` group. First login after enabling: log out and back in to pick up the new group.

### `~/code` btrfs drive + hourly btrbk snapshots

Declared in `code-drive.nix`, imported only into the `laptop` output (the VM has no code drive). Mirrors the ansible setup on minerva (`ops/local.code-drive.yml`).

**One-time bootstrap on a new laptop:**

1. Format the target disk (or partition) as btrfs with label `code`:
   ```
   sudo mkfs.btrfs -L code /dev/nvmeXnY
   ```
2. `sudo nixos-rebuild switch --flake .#laptop`. First boot will:
   - Mount the top of the btrfs filesystem (subvolid=5) at `/mnt/code-btr`.
   - Run the `code-drive-subvolumes.service` oneshot, which creates `@code` and `@snapshots` if missing and chowns `@code` to `tom:users`.
   - Mount `@code` at `~/code`.
   - Enable the `btrbk-code.timer` for hourly snapshots.
3. Migrate existing code (if any):
   ```
   rsync -aHAX --info=progress2 /old/path/to/code/ ~/code/
   ```

**Retention** (in `services.btrbk.instances.code.settings.snapshot_preserve`): `24h 14d 8w` — 24 hourly + 14 daily + 8 weekly. Minimum kept: 2h.

**Ops:**
```
btrbk -c /etc/btrbk/btrbk.conf list snapshots     # what's kept
btrbk -c /etc/btrbk/btrbk.conf run                # snapshot now
sudo systemctl status btrbk-code.timer            # timer status
journalctl -u btrbk-code.service -n 50            # recent runs
btrfs subvolume list /mnt/code-btr                # all subvols
```

Missing drive is safe: all fileSystems use `nofail`, so the machine still boots. The btrbk timer will just error out until the drive is present.

### 1Password

Desktop app + CLI both enabled. Polkit integration is granted to user `tom` for the system-auth prompts (Touch ID / kernel-key integration).

## Repo layout

```
nixos/
├── flake.nix              # inputs + `vm` and `laptop` outputs
├── flake.lock             # pinned input revs
├── configuration.nix      # base system: users, network, audio, ssh, docker, 1password
├── home.nix               # Home Manager: user packages, XDG_CONFIG_HOME → dotfiles
├── hyprland.nix           # Hyprland, greetd/tuigreet, portals, fonts
├── luks.nix               # LUKS device declaration (laptop only, placeholder UUID)
├── hardware-vm.nix        # qemu-guest profile + shared dotfiles dir
├── hardware-laptop.nix    # placeholder — replaced by nixos-generate-config at install
└── README.md              # this file
```

## Common gotchas

- **`Path 'nixos/flake.nix' is not tracked by Git`** — `git add nixos/` (staging is enough; you don't have to commit).
- **`attribute 'foo' missing` on rebuild** — package rename in nixpkgs. Check <https://search.nixos.org/packages>.
- **VM boots but Hyprland config is default** — the 9p share failed to mount. Check `dmesg` in the guest and that the host path exists.
- **Changed group membership doesn't take effect** — log out and back in (or reboot).
