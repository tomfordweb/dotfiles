# dotfiles

Personal dotfiles and NixOS configuration.

`config/` is the source of truth for app configs. `~/.config/<app>` is
symlinked into it, so edits apply immediately on every machine. `bin/`
goes on `$PATH`. How the symlinks get created depends on the machine:

- **NixOS hosts** (minerva, t480): home-manager — see [`nixos/README.md`](nixos/README.md)
- **Non-nix Linux** (work): `install/bootstrap.sh`
- **mac**: `install/bootstrap.sh --minimal` plus the terminfo fix below

## Repo map

```
bin/          scripts (llm, recording-light, devserver, wtport, ...)
config/       app configs — hypr, waybar, wofi, tmux, ghostty, nvim*, git, ...
docs/         personal wiki (submodule)
install/      bootstrap.sh (non-nix), macos-terminfo.sh, rice.sh, docker/
nixos/        flake: NixOS hosts + home-manager (see nixos/README.md)
rice/         shared SCSS palette for waybar/wofi themes
```

`*` submodules: `config/nvim` → [neotom](https://github.com/tomfordweb/neotom),
`config/waybar/custom/nvidia-smi`, `docs` → wiki. Changes to those are
committed in their own repos.

## Setup — NixOS hosts

See [`nixos/README.md`](nixos/README.md). Everything (packages, symlinks,
PATH, shell) comes from `nixos-rebuild switch`.

## Setup — non-nix hosts (work, mac)

```bash
git clone git@github.com:tomfordweb/dotfiles.git ~/code/tomfordweb/dotfiles
cd ~/code/tomfordweb/dotfiles && git submodule update --init

sh install/bootstrap.sh            # Linux desktop (incl. hypr/waybar/wofi)
sh install/bootstrap.sh --minimal  # work box / mac: dev core only

# then add to your shell rc:
export PATH="$HOME/code/tomfordweb/dotfiles/bin:$PATH"
```

The script refuses to clobber real files — if it prints `SKIP`, move the
existing `~/.config/<app>` aside and re-run. It is idempotent.

Tools the configs expect (install via apt/brew): git, tmux, neovim,
ghostty, lazygit, ripgrep, fd, fzf, jq, starship. On NixOS these are
declared in `nixos/home/`.

### mac extras

macOS ships an ancient ncurses whose `tmux-256color` terminfo is broken
(paste garbage, dead registers in nvim inside tmux). Once per mac:

```bash
sh install/macos-terminfo.sh
tmux kill-server
```

## Scripts

| Command | Use |
| --- | --- |
| [`llm`](bin/llm) | Register and serve models, chat, request JSON or embeddings, and benchmark. Start with `llm doctor`, `llm scan --register`, and `llm list`. |
| [`llm-pull OWNER/REPO FILE [REVISION]`](bin/llm-pull) | Download a Hugging Face file. Pin a commit SHA for reproducible downloads. |
| [`backup-llm-models --dry-run --verify`](bin/backup-llm-models) | Preview a checksum-based model backup to `/mnt/storage/llama-models`. Omit `--dry-run` to copy. Requires `/mnt/storage` mounted. Also available as `llm backup`. |
| [`recording-light toggle`](bin/recording-light) | Dim external DDC/CI monitors to 20%, then restore saved brightness on the next toggle. `off` restores; `on --dry-run` previews targets. See [Waybar setup](config/waybar/README.md#recording-light). |

For a local GGUF model:

```sh
llm add demo /path/to/model.gguf
llm serve demo                  # foreground server, CPU by default
llm chat demo "Hello"           # run in another terminal
```

Minerva declares model tools in [`nixos/modules/ai.nix`](nixos/modules/ai.nix).
Other hosts need Python 3, a model runtime, `hf` for downloads, and `rsync`
for backups. Downloads default to `/var/lib/llama-models`; set
`LLM_MODELS_DIR` to use another store. Use each command's `--help` for options.

## Claude

On NixOS, Home Manager wires skills from `ai-tools/`. Policy in
[`ai-tools/settings.json`](ai-tools/settings.json) becomes system managed
settings after a rebuild. `~/.claude/settings.json` stays writable for
Claude's runtime preferences; Home Manager seeds it only when missing or
replacing the old Nix store symlink.

## Ricing

Waybar/wofi styles are SCSS, compiled to CSS (never edit the `.css`
directly):

```bash
./install/rice.sh    # sass --watch for waybar + wofi themes
```

Palette colors live in `rice/palette.json`. After editing it, run
`bin/rice-build` to regenerate app themes, including Yazi, then recompile SCSS
with `install/rice.sh`.
