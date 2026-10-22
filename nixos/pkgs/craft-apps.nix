# ArtCraft "Crafting Apps" (clean-room Rust reimplementations of Adobe tools),
# packaged from the upstream AppImages. Not in nixpkgs. Every app publishes
# the same release layout: <name>-<version>-linux-x86_64.AppImage at the root
# holding ai.storyteller.<name>.{desktop,png}.
#
# Bump an app: set version, then
#   nix store prefetch-file --json <AppImage url> | jq -r .hash
# and check it against that release's SHA256SUMS.txt.
#
# The apps open on the workspace they were launched from, and wgpu prefers the
# integrated GPU by default (WGPU_POWER_PREF=high picks the NVIDIA card).
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  apps = {
    photocraft = {
      repo = "photocraft";
      version = "0.3.0";
      hash = "sha256-KeMBH0mlLqJcj+QEJYpsX62wIJTbtAqITWnmuoCOYTY=";
      description = "Photoshop-style raster editor";
    };
    lightcraft = {
      repo = "lightcraft";
      version = "0.2.1";
      hash = "sha256-wvOa2qimU21QFKe6EC/3heGjI6AuCJ0B2x+FN43A/FM=";
      description = "Lightroom-style photo developer";
    };
    filmcraft = {
      repo = "filmcraft";
      version = "0.2.1";
      hash = "sha256-eJHJskyOFlpUkG+O5qaXPgUd08LMH6Jymngmn+xIEYg=";
      description = "Premiere Pro-style video editor";
    };
    vectorcraft = {
      repo = "vectorcraft";
      version = "0.4.0";
      hash = "sha256-/0c/IAsBA2AtToPgC7VlKE0qsDRFqa0vdr+P/bMC2FA=";
      description = "Illustrator-style vector editor";
    };
    # PdfCraft: the repo kept its name, the release assets became printcraft-*.
    printcraft = {
      repo = "pdfcraft";
      version = "0.2.1";
      hash = "sha256-QBc1xka8WITPH/eZ1GkTvOfcPSnQb/WikCaX5lRl9YQ=";
      description = "Acrobat-style PDF workbench";
    };
  };

  mkCraftApp =
    pname: app:
    let
      inherit (app) version;
      src = fetchurl {
        url = "https://github.com/storytold/${app.repo}/releases/download/v${version}/${pname}-${version}-linux-x86_64.AppImage";
        inherit (app) hash;
      };
      contents = appimageTools.extract { inherit pname version src; };
      id = "ai.storyteller.${pname}";
    in
    appimageTools.wrapType2 {
      inherit pname version src;

      # Desktop entry + icon so it shows up in wofi and as a file handler.
      extraInstallCommands = ''
        install -Dm644 ${contents}/${id}.desktop $out/share/applications/${id}.desktop
        install -Dm644 ${contents}/${id}.png $out/share/icons/hicolor/256x256/apps/${id}.png
      '';

      meta = {
        description = "${app.description} (ArtCraft, upstream AppImage)";
        homepage = "https://github.com/storytold/${app.repo}";
        license = with lib.licenses; [ mit asl20 ];
        platforms = [ "x86_64-linux" ];
        mainProgram = pname;
      };
    };
in
lib.mapAttrs mkCraftApp apps
