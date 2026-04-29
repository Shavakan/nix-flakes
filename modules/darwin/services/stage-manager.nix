# modules/darwin/services/stage-manager.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.custom.stageManager;

  # Create a small utility package to toggle Stage Manager
  stageManagerToggle = pkgs.writeScriptBin "toggle-stage-manager" ''
    #!/bin/bash
    
    # Get current Stage Manager status
    current=$(defaults read com.apple.WindowManager GloballyEnabled 2>/dev/null || echo "0")
    
    # Toggle Stage Manager
    if [ "$current" = "1" ]; then
      defaults write com.apple.WindowManager GloballyEnabled -bool false
      # Show notification that Stage Manager is disabled
      osascript -e 'display notification "Stage Manager disabled" with title "Window Management"'
    else
      defaults write com.apple.WindowManager GloballyEnabled -bool true
      # Show notification that Stage Manager is enabled
      osascript -e 'display notification "Stage Manager enabled" with title "Window Management"'
    fi
    
    # Restart Dock to apply changes
    killall Dock
  '';
in
{
  options.custom.stageManager = {
    enable = mkEnableOption "Stage Manager toggle support";

    createDesktopShortcut = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to create a desktop shortcut for toggling Stage Manager";
    };

    defaultEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Whether Stage Manager should be enabled by default";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ stageManagerToggle ];
  };
}
