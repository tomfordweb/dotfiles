#!/bin/bash
# scripting to get AI up and running in docker containers on Arch Linux
#
# Graphics Card: 
#   - 980GTX 
#   - NV124 (NV110 Family (Maxwell))
# First , install nvidia as it is recommended by arch wiki. I am also on the linux kernel and not linux-lts in which case you would want nvidia-lts
sudo pacman --needed -Sy nvidia ollama-cuda
# These was some configuration pain here where I got a black screen when using USWM managed hyprland.
# However starting hyprland from a TTY or non uswm managed hyperland and everything works!
#   This also fixes some stuttering and mouse cursor issues, definetly the right direction but I am kind of an idiot with systemd
# It probably has to do with the kernel modules
# I also edited.
# /etc/mkinitcpio.conf to include:
# MODULES=(... nvidia nvidia_modeset nvidia_uvm nvidia_drm)

# Docker AI+GPU
sudo pacman --needed -Sy libnvidia-container nvidia-utils opencl-nvidia nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
docker run --gpus all nvidia/cuda:13.0.2-base-ubi9 nvidia-smi


# Systemd unit
sudo systemctl enable ollama.service



