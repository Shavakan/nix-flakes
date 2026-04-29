# modules/darwin/services/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./stage-manager.nix
  ];

  # Configure the custom Stage Manager service
  custom.stageManager = {
    enable = true;
    createDesktopShortcut = true;
    defaultEnabled = true;
  };
}
