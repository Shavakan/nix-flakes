{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone-launchd;
  
  # This module requires the rclone-mount service
  mountService = config.services.rclone-mount;
  
  # Create a script for the LaunchAgent that uses the rclone-mount script
  launchdScript = pkgs.writeShellScript "rclone-launchd-script" ''
    #!${pkgs.bash}/bin/bash
    
    # Function to check if a path is mounted silently
    is_mounted_path() {
      /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$1"
      return $?
    }
    
    # Path to the rclone-mount command from the profile
    RCLONE_MOUNT_CMD="${config.home.profileDirectory}/bin/rclone-mount"
    
    # Use the rclone-mount command for each mount point
    ${concatMapStringsSep "\n" (mount: ''
      if ! is_mounted_path "${mount.mountPoint}"; then
        # Use the mount script from rclone-mount module
        "$RCLONE_MOUNT_CMD" "${mount.remote}" "${mount.mountPoint}" >/dev/null 2>&1
      fi
    '') mountService.mounts}
  '';
  
in {
  options.services.rclone-launchd = {
    enable = mkEnableOption "rclone mount launchd service";
  };
  
  config = mkIf (cfg.enable && mountService.enable) {
    # Add a LaunchAgent to automatically mount at login
    launchd.agents.rclone-mount = {
      enable = true;
      config = {
        Label = "com.rclone.mount";
        ProgramArguments = [
          "${pkgs.bash}/bin/bash"
          "${launchdScript}"
        ];
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/rclone-mount.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/rclone-mount.error.log";
        EnvironmentVariables = {
          # Ensure PATH includes the user profile
          PATH = "${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          # Include HOME to ensure rclone finds its config
          HOME = "${config.home.homeDirectory}";
        };
      };
    };
  };
}
