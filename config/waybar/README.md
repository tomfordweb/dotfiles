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

Install `ddcutil` and enable DDC/CI in the monitors' menus. The current user
needs access to their `/dev/i2c-*` devices. On Minerva, the existing OpenRGB
setup already provides access. Install the command without a system rebuild:

```sh
nix profile add nixpkgs#ddcutil
```

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
