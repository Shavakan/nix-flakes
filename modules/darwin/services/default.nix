# modules/darwin/services/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./stage-manager.nix
  ];
  
  # Configure the custom Stage Manager service
  custom.stageManager = {
    enable = true;
    keyboard = {
      enableShortcuts = true;
      shortcuts = [ "cmd + alt - s" ];
    };
    createDesktopShortcut = true;
    defaultEnabled = true;
  };
}
