# Getting started

```bash
git clone git@github.com:tomfordweb/xdg-base.git
cd xdg-base && git submodule update --init
```

Add the following your your `~/.bashrc` or whatever.

```bash
export XDG_CONFIG_HOME="$HOME/xdg-base/config"
```

On Arch - [You also have to add the env var to pam.](https://wiki.archlinux.org/title/Environment_variables#Using_pam_env)

```bash
sudo vim /etc/security/pam_env.conf
```

```bash
XDG_CONFIG_HOME DEFAULT=@{HOME}/xdg-base/config
```

Source it.

```bash
source ~/.bashrc
```

# System setup tips

Add system wide environment variables to `/etc/environment`.

```bash
EDITOR=nvim

```

# Development

## Ricing

Most of my CSS is written with sass. You can run the script to watch supported files and write to their respective .css files with

```
./bin/rice.sh
```

# Scripts

## `./bin/ai/arch.setup.sh`

Sets up ollama in docker on arch linux for my specific use case, there are some notes that maybe some will find useful.

# Arch

- [yay](https://github.com/Jguer/yay)
- [t480 arch](https://wiki.archlinux.org/title/Lenovo_ThinkPad_T48)
