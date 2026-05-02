# Environment and .config directory setup

```bash
git clone git@github.com:tomfordweb/dotfiles.git ~/code/tomfordweb/dotfiles
cd dotfiles && git submodule update --init
```
Add the following your your `~/.bashrc` or whatever.

```bash
export XDG_CONFIG_HOME="$HOME/code/tomfordweb/dotfiles/config"
export PATH=/$HOME/code/tomfordweb/dotfiles/bin:$PATH
```

Source it.

```bash
source ~/.bashrc
```

### Arch linux

On Arch - [You also have to add the env var to pam.](https://wiki.archlinux.org/title/Environment_variables#Using_pam_env)

```bash
sudo vim /etc/security/pam_env.conf
...
XDG_CONFIG_HOME DEFAULT=@{HOME}/xdg-base/config
```

### Mac

I have had a hard time getting ghostty to read my config file after having a nonstandard XDG_CONFIG_HOME on a mac.

This however can be amended by symlinking the config to one of the other places that ghostty looks.

```
ln -s $XDG_CONFIG_HOME/ghostty/config $HOME/.config/ghostty/config
```


# /etc/environment

Add system wide environment variables to `/etc/environment`.

```bash
EDITOR=nvim

```


# Ricing & Development

Most of my CSS is written with sass. You can run the script to watch supported files and write to their respective .css files with

```
./bin/rice.sh
```
# Programs

* [oh my bash](https://github.com/ohmybash/oh-my-bash)
* [yay](https://github.com/Jguer/yay)
* [pnpm](https://pnpm.io/installation)


# Arch Wiki

* [t480 arch](https://wiki.archlinux.org/title/Lenovo_ThinkPad_T48)
