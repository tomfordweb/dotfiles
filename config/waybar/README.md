# Requirements

- "Big Blue nerd plus" Nerd font.
- `gpsd`

# Custom plugins

### `custom/docker-status`

Shows the status of the docker daemon. You can hover it to show which containers are running.

### `custom/pacman-status`

Shows the status of pacman registry.

# Recording light

The Display light button dims connected DDC/CI monitors to 20% for camera
recording. It changes the monitors' hardware brightness, so screen captures
keep their original colors and brightness. Click Recording light to restore
each monitor's previous setting. The button shows progress and errors.

Enable DDC/CI in the monitors' menus. NixOS desktop configurations install
`ddcutil`, enable I2C, and add `tom` to the `i2c` group. Rebuild and log in
again to apply these dependencies. On non-Nix Linux hosts, install `ddcutil`
with the distribution's package manager and grant the current user access
to `/dev/i2c-*`. Laptop panels do not support DDC/CI; connect an external
monitor that supports it.

The same control is available from a terminal:

```sh
recording-light on --dry-run       # inspect targets without changing displays
recording-light on --level 15      # use a different recording brightness
recording-light off                # restore saved brightness
recording-light status             # inspect saved settings and errors
```

Restore values live in `$XDG_STATE_HOME/recording-light/state.json`, defaulting
to `~/.local/state/recording-light/state.json`. They survive restarts. If a
monitor disconnects or a write fails, its restore value stays saved. Reconnect
it and click again to finish restoring. Do not delete the state file while
restoration is pending. Displays already below the recording level stay dim.

# Development

Run the brightness restore tests with `python3 -m unittest discover -s tests`.

```
GTK_DEBUG=interactive waybar
sass --watch theme.scss style.css
```
