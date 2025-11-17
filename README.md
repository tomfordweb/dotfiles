
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


