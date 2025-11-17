#!/bin/bash

# scripting to get AI up and running in docker containers on Arch Linux
#
# Graphics Card: 
#   - 980GTX 
#   - NV124 (NV110 Family (Maxwell))
# First , install nvidia as it is recommended by arch wiki. I am also on the linux kernel and not linux-lts in which case you would want nvidia-lts
sudo pacman --needed -Sy nvidia
sudo pacman --needed -Sy libnvidia-container nvidia-utils opencl-nvidia nvidia-container-toolkit

