```
git clone git@github.com:tomfordweb/xdg-base.git
cd xdg-base && git submodule update --init
```

Add the following your your `~/.bashrc` or whatever.

```
export XDG_CONFIG_HOME="$HOME/xdg-base/config"
```

Source it.

```
source ~/.bashrc
```

# Scripts

## `./bin/ai/arch.setup.sh`

Sets up ollama in docker on arch linux for my specific use case, there are some notes that maybe some will find useful.

# Arch

- [yay](https://github.com/Jguer/yay)
- [t480 arch](https://wiki.archlinux.org/title/Lenovo_ThinkPad_T48)
