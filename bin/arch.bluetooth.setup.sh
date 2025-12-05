#!/bin/bash

if !lsmod | grep btusb; then 
  echo "bluetooth is not enabled on the kernel!"; 
  exit 1; 
fi

sudo pacman -Syu blueman pulseaudio-bluetooth

sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service


killall pulseaudio
pulseaudio --start

sudo systemctl restart bluetooth.service
