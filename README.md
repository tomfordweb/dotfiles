This repository contains all of my keymaps for my QMK Keyboards.

# Flashing Notes

Don't forget to run these commands on your first setup.

```
qmk setup
qmk doctor
```

### RGBKB Mun

Make sure to use dfu-util to build the left and right firmware individually.

Note: If this ever gets merged into its upsreaam, you can remove this fork.

```
cd ~/code/rgbkb/qmk_firmware
qmk flash -kb rgbkb/mun -km tom-custom -bl dfu-util-split-left
qmk flash -kb rgbkb/mun -km tom-custom -bl dfu-util-split-right
```

### Helix

Rinse and repeat for both halves

```
make helix:tom-custom:flash
```
