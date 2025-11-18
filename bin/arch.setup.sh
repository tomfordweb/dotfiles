#!/bin/bash

sudo pacman --needed -Sy \
git lazygit \
firefox \
ghostty \
otf-font-awesome \
tmux \
entr \
pciutils \
docker docker-compose

./bin/setupDocker.sh


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

# Install neovim.
echo "Running nvim playbook"
if ! command -v "nvim" &> /dev/null; then
  sudo pacman --needed -Sy ansible make cmake jp2a
  ansible-playbook install_nvim.playbook.yml --ask-become-pass
else
  echo "neovim is already installed!"
fi

# Install any things i think nvim needs
./config/nvim/installDependencies.sh

# Tmux plugin manager
# After install you need to hit <C-a I> and wait a few seconds..
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

./bin/ai/arch.setup.sh
