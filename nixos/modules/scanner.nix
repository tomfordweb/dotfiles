{ pkgs, ... }:

# ------------------------------------------------------------------
# Scanner — Canon CanoScan 9000F Mark II (USB 04a9:190d) on the t480.
# ------------------------------------------------------------------
# A CCD flatbed with a transparency unit for film/negatives. It is
# supported out of the box by SANE's free `pixma` backend (recognised
# as pixma:04A9190D since libsane 1.0.24) — NO proprietary Canon
# ScanGear blob and NO firmware download are needed.
#
# hardware.sane.enable pulls in sane-backends (incl. pixma), installs
# the /etc/udev libsane rules that tag the device, and creates the
# `scanner` group that owns it. tom must be in that group (below) to
# reach the device without root.
#
# Quick verification after a rebuild + replug:
#   scanimage -L                       # should list `pixma:04A9190D`
#   scanimage --format=png > test.png  # grab a scan from the CLI
#
# If `scanimage -L` shows nothing: unlock the transport lock on the
# left edge of the lid (ships locked for shipping) and re-plug USB.

{
  hardware.sane.enable = true;   # sane-backends + pixma + udev rules + `scanner` group

  # Merges with the base list in modules/core.nix (NixOS concatenates
  # extraGroups across modules). `scanner` owns the USB device node;
  # `lp` covers the parallel/print side some SANE backends touch.
  users.users.tom.extraGroups = [ "scanner" "lp" ];

  environment.systemPackages = with pkgs; [
    xsane         # full-control GUI — film/negative modes, 48-bit, high-DPI, batch
    simple-scan   # one-click document scans (nicer UI for the trivial case)
  ];
}
