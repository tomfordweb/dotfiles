#!/bin/bash

if !lsmod | grep btusb; then 
  echo "bluetooth is not enabled on the kernel!"; 
  exit 1; 
fi

sudo pacman -Syu bluez bluez-utils

sudo systemctl enable bluetooth.service
sudo systemctl start bluetooth.service

