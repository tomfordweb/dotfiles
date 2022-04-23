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
- Boot up nvim, embrace the errors
- Run `:PluginInstall`
- Run `:so` (source mapping) or just restart it.

### `arch.yml`

- i3-gaps config
- conky
- xorg modifications
  - caps as ctrl
