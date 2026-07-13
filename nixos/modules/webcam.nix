{ pkgs, ... }:

# ------------------------------------------------------------------
# Webcam tooling — EMEET SmartCam S600 (USB 328f:00e6) on minerva.
# ------------------------------------------------------------------
# The S600 is a plug-and-play UVC device: 4K MJPG (up to 4K@30,
# 1080p@60), 2 mics and PDAF autofocus all work with NO driver. It has
# NO on-device AI subject-tracking or gesture control — those belong to
# EMEET's PIXY, not the S600. EMEET's EMEETLINK tuning/firmware app is
# Windows/macOS only, so image tuning is done here via v4l2 controls
# (guvcview / v4l2-ctl) instead. OBS + virtual camera is the software
# route to auto-framing / tracking that the hardware doesn't provide.
#
# tom is already in the `video` group (modules/core.nix), so no extra
# permissions are needed.

{
  environment.systemPackages = with pkgs; [
    v4l-utils   # v4l2-ctl: list formats, set focus/exposure/power-line-freq
    guvcview    # GUI EMEETLINK replacement — live focus/exposure/WB tuning
    cheese      # quick capture / verify the cam works
  ];

  # Persist sane image defaults. v4l2 controls are runtime-only and reset
  # on every replug/reboot; this udev rule re-applies them when the S600
  # appears. index=="0" targets the capture node (video0), not the sibling
  # metadata node. Out of the box brightness ships at 33 (near-black); 128
  # is the sensor default, gain + backlight_compensation lift the subject
  # against bright backlighting (windows). Tune live in guvcview, then move
  # the winning values here.
  services.udev.extraRules = ''
    SUBSYSTEM=="video4linux", ATTRS{idVendor}=="328f", ATTRS{idProduct}=="00e6", ATTR{index}=="0", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl -d $devnode -c brightness=128 -c gain=40 -c backlight_compensation=2"
  '';

  # OBS at system level (not home-manager) so enableVirtualCamera can set
  # up the v4l2loopback kernel module + polkit — the virtual cam that
  # Zoom/Meet/etc. then consume.
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-backgroundremoval   # AI background removal / masking
    ];
  };
}
