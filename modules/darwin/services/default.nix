# modules/darwin/services/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./skhd.nix
    ./stage-manager.nix
  ];

  # Enable centralized skhd management
  custom.skhd = {
    enable = true;
    extraConfig = [
      # Add any additional skhd shortcuts here
      # Example: "cmd + shift - t : open -a Terminal"
    ];
  };

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
