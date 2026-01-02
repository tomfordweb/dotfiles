#!/bin/bash

# Docker post installation stuff.

if ! getent group docker >/dev/null; then
  sudo groupadd docker
fi

sudo usermod -aG docker $USER

# Use docker.socket to boot docker on first container start
# which should decrease boot times.
sudo systemctl enable docker.socket
sudo systemctl start docker.socket

docker run hello-world
