{ modulesPath, lib, config, pkgs, ... }:

{
  imports = [
    "${toString modulesPath}/installer/cd-dvd/iso-image.nix"
  ];

  isoImage = {
    isoName = "${config.isoImage.isoBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.iso";
    volumeID = lib.substring 0 11 "NIXOS_ISO";
    makeEfiBootable = true;
    makeUsbBootable = true;
    appendToMenuLabel = "live";
    squashfsCompression = "gzip -Xcompression-level 1";
  };
}
