```
git clone git@github.com:tomfordweb/xdg-base.git
cd xdg-base && git submodule update --init
```

Add the following your your `~/.bashrc` or whatever.

```
export XDG_CONFIG_HOME="$HOME/xdg-base/config"
```

On Arch - [You also have to add the env var to pam.](https://wiki.archlinux.org/title/Environment_variables#Using_pam_env)

```
sudo vim /etc/security/pam_env.conf
```
```
XDG_CONFIG_HOME DEFAULT=@{HOME}/xdg-base-config
```

Source it.

```
source ~/.bashrc
```

# Scripts

## `./bin/ai/arch.setup.sh`

Sets up ollama in docker on arch linux for my specific use case, there are some notes that maybe some will find useful.
