# 'nix Setup

- Install ansible locally
- Add the following galaxy modules
  - `ansible-galaxy collection install community.general`
  - `ansible-galaxy install kewlfft.aur` (necessary for arch, otherwise ignore)

# Mac Setup

Just use a venv. I have never been able to get ansible working well on a mac

```
$ python3 -m venv venv
$ source venv/bin/activate
$ python -m pip install ansible
```

# Playbooks

### `devmachine.yml`

```
ansible-playbook devmachine.yml --ask-become-pass
```

Cross platform text editor and terminal configuration.

- gruvbox
- alacritty
- tmux
- nvim
- lunarvim
- docker
- local build tools

#### Tags:

- `vimrc` - update vim configs

#### Post Run Steps:

- Set a default node via nvm, I use LTS versions

### `arch.yml`

- i3-gaps config
- conky
- xorg modifications
  - caps as ctrl

# Keyboards: 

This repository contains all of my keymaps for my QMK Keyboards.

## Flashing Notes

Don't forget to run these commands on your first setup.

```
qmk setup
qmk doctor
```

### RGBKB Mun

Make sure to use dfu-util to build the left and right firmware individually.

Note: If this ever gets merged into its upsreaam, you can remove this fork.

```
cd ~/code/rgbkb/qmk_firmware
qmk flash -kb rgbkb/mun -km tom-custom -bl dfu-util-split-left
qmk flash -kb rgbkb/mun -km tom-custom -bl dfu-util-split-right
```

### Helix

Rinse and repeat for both halves

```
make helix:tom-custom:flash
```
