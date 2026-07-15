# Official Bambu Studio, packaged from the upstream AppImage.
#
# WHY NOT nixpkgs `bambu-studio`: the 02.08.x nixpkgs source build renders a
# BLANK 3D bed on minerva (an in-build bug — the GL stack is healthy: glxgears
# / glxinfo work, and it stayed blank even under software rendering). This wraps
# the official AppImage instead, which renders correctly.
#
# THE TRICKY PART — the blank bed here was an EGL/GL-vendor problem: the
# AppImage's own `AppRun` does `export LD_LIBRARY_PATH="$DIR/bin"` (an
# OVERWRITE, not append), which wipes any path to the NVIDIA driver. The FHS
# then falls back to Mesa's EGL, which cannot drive the proprietary card ->
# no GL context -> blank 3D viewport. Fix: bypass AppRun and launch
# `bin/bambu-studio` directly with the NVIDIA vendor libs (/run/opengl-driver)
# + the glvnd dispatcher (libglvnd) prepended to LD_LIBRARY_PATH, where nothing
# clobbers them. (The `libEGL warning ... dri2` log noise is just glvnd probing
# Mesa first, then falling back to NVIDIA — harmless.)
#
# Other FHS-sandbox fixes folded in:
#  - glibcLocales (LOCALE_ARCHIVE)  -> kills "Switching language failed"
#  - glib-networking (GIO modules)  -> kills "TLS support is not available"
#  - cacert (SSL_CERT_FILE)         -> TLS trust store for login/plugin/printer
{
  lib,
  appimageTools,
  buildFHSEnv,
  writeShellScript,
  fetchurl,
  glibcLocales,
  libglvnd,
  cacert,
  glib-networking,
  webkitgtk_4_1,
  libsoup_3,
  gst_all_1,
}:

let
  pname = "bambu-studio-appimage";
  version = "02.07.01.62";
  gst = gst_all_1;

  src = fetchurl {
    url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/BambuStudio_ubuntu24.04-v${version}-20260616195227.AppImage";
    hash = "sha256-+pi2CFMt+7uysJMUg6rEHlf7GcF1osx719Uo1eD7soc=";
  };

  contents = appimageTools.extract { inherit pname version src; };
  fhs = appimageTools.defaultFhsEnvArgs;

  # Run bin/bambu-studio DIRECTLY (not via AppRun — see header note).
  runScript = writeShellScript "${pname}-run" ''
    export LC_ALL=C                                   # AppRun's own segfault workaround
    # Full locale archive so Bambu can switch UI language (e.g. wxWidgets maps
    # "en" -> en_GB). glibc >= 2.27 reads LOCALE_ARCHIVE_2_27 FIRST, and the FHS
    # sets that to a minimal en_US-only archive — so we must override BOTH, else
    # "Switching Bambu Studio to language en_GB failed" (missing locale).
    export LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive
    export LOCALE_ARCHIVE_2_27=${glibcLocales}/lib/locale/locale-archive
    export LD_LIBRARY_PATH=${contents}/bin:/run/opengl-driver/lib:${libglvnd}/lib
    export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    export SSL_CERT_DIR=${cacert}/etc/ssl/certs
    export CURL_CA_BUNDLE=${cacert}/etc/ssl/certs/ca-bundle.crt
    export GIO_EXTRA_MODULES=${glib-networking}/lib/gio/modules
    export GST_PLUGIN_SYSTEM_PATH_1_0=${gst.gst-plugins-good}/lib/gstreamer-1.0:${gst.gst-plugins-bad}/lib/gstreamer-1.0:${gst.gst-libav}/lib/gstreamer-1.0:${gst.gst-plugins-base}/lib/gstreamer-1.0
    exec ${contents}/bin/bambu-studio "$@"
  '';
in
buildFHSEnv {
  inherit pname version;

  targetPkgs =
    p:
    (fhs.targetPkgs p)
    ++ (fhs.multiPkgs p)
    ++ (with p; [
      webkitgtk_4_1 # libwebkit2gtk-4.1 — the lib bare appimage-run lacked
      libsoup_3
      glib-networking
      cacert
      glibcLocales
      libglvnd
      gst.gstreamer
      gst.gst-plugins-base
      gst.gst-plugins-good
      gst.gst-plugins-bad
      gst.gst-libav # printer camera (H.264/mjpeg)
    ]);

  runScript = "${runScript}";

  # Desktop entry + icon so it appears in wofi as "Bambu Studio".
  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/icons/hicolor/256x256/apps
    cp ${contents}/BambuStudio.png \
       $out/share/icons/hicolor/256x256/apps/${pname}.png
    substitute ${contents}/BambuStudio.desktop \
       $out/share/applications/${pname}.desktop \
       --replace-quiet 'Exec=AppRun'        'Exec=${pname}' \
       --replace-quiet 'Icon=BambuStudio'   'Icon=${pname}' \
       --replace-quiet 'Name=BambuStudio'   'Name=Bambu Studio'
  '';

  meta = {
    description = "Official Bambu Studio slicer (upstream AppImage, NVIDIA-EGL fixed for minerva)";
    homepage = "https://github.com/bambulab/BambuStudio";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
