# Installation

Clone the repo somewhere in your home directory. It does not have to be the `~/.config` directory. For example. I keep mind in `~/xdg-base`.

```
git clone git@github.com:tomfordweb/xdg-base.git ~/.config
```

Initialize submodules

```
git submodule update --init
```

Add the following your your profile.

```
export XDG_CONFIG_HOME="$HOME/.config"
source ~/.bashrc
```
