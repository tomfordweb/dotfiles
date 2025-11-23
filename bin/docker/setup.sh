#!/bin/bash

# Docker post installation stuff.

if ! getent group docker >/dev/null; then
  sudo groupadd docker
fi

sudo usermod -aG docker $USER

sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo systemctl enable containerd.service
sudo systemctl start containerd.service

docker run hello-world
