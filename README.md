# Linux Setup

- Install ansible locally
- Add the following galaxy modules
  - `ansible-galaxy collection install community.general`
  - `ansible-galaxy install kewlfft.aur` (necessary for arch, otherwise ignore)

# Mac Setup

I like using ansible in a venv on Macs.

```
$ python3 -m venv venv
$ source venv/bin/activate
$ python -m pip install ansible
```

# Adding a new role

```
ansible-galaxy init roles/<your role name>
```

# Playbooks

### `install_nvim.yml`
Removes and re-installs install_nvim

```
ansible-playbook install_nvim.yml --ask-become-pass

```

### `devmachine.yml`

```
ansible-playbook devmachine.yml --ask-become-pass
```

Cross platform text editor and terminal configuration.

- gruvbox
- alacritty
- tmux
- nvim & dependencies
- docker
- local build tools

#### Tags:

- `vimrc` - update vim configs
- `dotfiles` - replace all dotfiles (tmux, alacritty, nvim)

#### Post Run Steps:

- Set a default node via nvm, I use LTS versions


# Keyboards: 

This playbook contains all of my keymaps and firmware for the open source QMK keyboards I use.

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
