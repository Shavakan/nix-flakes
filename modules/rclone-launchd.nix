{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone-launchd;
  
  # This module requires the rclone-mount service
  mountService = config.services.rclone-mount;
  
  # Create a script for the LaunchAgent that uses the rclone-mount script
  launchdScript = pkgs.writeShellScript "rclone-launchd-script" ''
    #!${pkgs.bash}/bin/bash
    # Exit if rclone conf doesn't exist
    if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
      ${pkgs.coreutils}/bin/echo "No rclone configuration found. Exiting."
      exit 1
    fi
    
    # Function to check if a path is mounted
    is_mounted() {
      /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$1"
      return $?
    }
    
    # Path to the rclone-mount command from the profile
    RCLONE_MOUNT_CMD="${config.home.profileDirectory}/bin/rclone-mount"
    RCLONE_STATUS_CMD="${config.home.profileDirectory}/bin/rclone-status"
    
    # Log startup
    ${pkgs.coreutils}/bin/echo "Starting rclone mounts at $(${pkgs.coreutils}/bin/date)"
    
    # Check for existing mounts first
    $RCLONE_STATUS_CMD
    
    # Use the rclone-mount command for each mount point
    ${concatMapStringsSep "\n" (mount: ''
      if ! is_mounted "${mount.mountPoint}"; then
        ${pkgs.coreutils}/bin/echo "Mounting ${mount.remote} to ${mount.mountPoint}..."
        "$RCLONE_MOUNT_CMD" "${mount.remote}" "${mount.mountPoint}"
        ${pkgs.coreutils}/bin/sleep 2 # Give mount time to initialize
      else
        ${pkgs.coreutils}/bin/echo "${mount.mountPoint} is already mounted"
      fi
    '') mountService.mounts}
    
    # Verify mounts were successful
    ${pkgs.coreutils}/bin/echo "\nVerifying mounts:"
    $RCLONE_STATUS_CMD
  '';
  
in {
  options.services.rclone-launchd = {
    enable = mkEnableOption "rclone mount launchd service";
  };
  
  config = mkIf (cfg.enable && mountService.enable) {
    # Make sure we have the required packages
    home.packages = with pkgs; [
      bash
      coreutils
      gnugrep
    ];
    
    # Ensure home directory exists for activation scripts
    home.activation.ensureRcloneDirs = lib.hm.dag.entryBefore ["writeBoundary"] ''
      ${concatMapStringsSep "\n" (mount: ''
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "${mount.mountPoint}"
      '') mountService.mounts}
    '';
    
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
          PATH = "${config.home.profileDirectory}/bin:$PATH";
        };
      };
    };
    
    # Create an activation script to mount the remotes during home-manager switch
    home.activation.mountRcloneRemotes = lib.hm.dag.entryAfter ["decryptRcloneConfig"] ''
      # Execute the mount script
      if [ -f "$HOME/.config/rclone/rclone.conf" ]; then
        $DRY_RUN_CMD ${launchdScript}
      fi
    '';
  };
}
