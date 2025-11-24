#!/bin/bash

# Mom - we already have a server at home
# the server at home...
sudo pacman --needed -Sy openssh ufw
sudo systemctl start sshd
sudo systemctl enable sshd
sudo ufw allow 22/tcp
sudo ufw enable
