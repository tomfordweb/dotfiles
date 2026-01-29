#!/bin/bash


sudo pacman --needed -Sy \
git lazygit \
spotify-launcher \
networkmanager \
pacman-contrib \
libnotify dunst \
snapper pacsnap \
paccache \
hyprpolkitagent \
alsa-utils \
rsync \
firefox \
rust \
ghostty \
otf-font-awesome \
tmux \
lsof \
sqlitebrowser mysql-workbench \
entr \
nvm \
pciutils \
lsof \
fastfetch \
libnewt \
docker docker-compose

# Setup nvm
source /usr/share/nvim/init-nvm.sh
nvm install --lts

./bin/setupDocker.sh

amixer sset Master unmute

# Waybar & deps
sudo pacman --needed -Sy \
  waybar \
  gtkmm3 \
  jsoncpp \
  libsigc++ \
  fmt \
  wayland \
  chrono-date \
  spdlog \
  gtk3 \
  gobject-introspection \
  libgirepository \
  libpulse \
  libnl \
  libappindicator-gtk3 \
  libdbusmenu-gtk3 \
  libmpdclient \
  sndio \
  libevdev \
  libxkbcommon \
  upower \
  meson \
  cmake \
  scdoc \
  wayland-protocols \
  glib2-devel

systemctl --user enable --now waybar.service

# Install neovim.
echo "Running nvim playbook"
if ! command -v "nvim" &> /dev/null; then
  sudo pacman --needed -Sy ansible make cmake jp2a
  ansible-playbook install_nvim.playbook.yml --ask-become-pass
else
  echo "neovim is already installed!"
fi

# Tmux plugin manager
# After install you need to hit <C-a I> and wait a few seconds..
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

sudo systemctl enable paccache.timer
sudo systemctl start paccache.timer
# ./bin/ai/arch.setup.sh
#
yay -Syu opentabletdriver
