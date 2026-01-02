#!/bin/bash

# Sass watcher for all of my gtk styled stuff
# It's been like 10 years since I have used gulp and I refuse to go back.

sass -I ./rice --watch \
  config/wofi/theme.scss:config/wofi/style.css \
  config/waybar/theme.scss:config/waybar/style.css

