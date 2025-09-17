# modules/darwin/services/skhd.nix
# Centralized skhd configuration to prevent multiple instances
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.custom.skhd;
  
  # Combine all skhd configurations from different modules
  combinedConfig = concatStringsSep "\n" (
    cfg.extraConfig ++
    (optional config.custom.stageManager.keyboard.enableShortcuts
      (concatStringsSep "\n" (map
        (shortcut: "${shortcut} : /run/current-system/sw/bin/toggle-stage-manager")
        config.custom.stageManager.keyboard.shortcuts
      ))
    )
  );
in
{
  options.custom.skhd = {
    enable = mkEnableOption "centralized skhd configuration";
    
    extraConfig = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional skhd configuration lines";
    };
  };

  config = mkIf (cfg.enable || config.custom.stageManager.keyboard.enableShortcuts) {
    # Ensure only one skhd service is configured
    services.skhd = {
      enable = true;
      package = pkgs.skhd;
      skhdConfig = combinedConfig;
    };
    
    # Add debugging/monitoring script
    environment.systemPackages = [
      (pkgs.writeScriptBin "skhd-status" ''
        #!/bin/bash
        echo "=== skhd Service Status ==="
        launchctl list | grep -i skhd || echo "No skhd service found"
        echo ""
        echo "=== skhd Processes ==="
        ps aux | grep -i skhd | grep -v grep || echo "No skhd processes running"
        echo ""
        echo "=== skhd Configuration ==="
        if [ -f /etc/skhdrc ]; then
          echo "Config file: /etc/skhdrc"
          echo "Contents:"
          cat /etc/skhdrc
        else
          echo "No config file found at /etc/skhdrc"
        fi
        echo ""
        echo "=== macOS Accessibility Permissions ==="
        echo "Check System Settings > Privacy & Security > Accessibility for skhd"
      '')
    ];
  };
}