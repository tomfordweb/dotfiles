#!/bin/bash

# Rice pipeline: render palette-driven configs, then watch the sass
# sources. rice/palette.json is the single source of truth for colors —
# bin/rice-build regenerates hypr/tmux/ghostty/mako configs and the
# _palette.scss the sass targets import.
# It's been like 10 years since I have used gulp and I refuse to go back.

cd "$(dirname "$0")/.." || exit 1

bin/rice-build

sass -I ./rice --watch \
  config/wofi/theme.scss:config/wofi/style.css \
  config/waybar/theme.scss:config/waybar/style.css \
  config/waybar/theme-pro.scss:config/waybar/style-pro.css \
  config/eww/theme.scss:config/eww/eww.css
