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
    
    # Function to check if a path is mounted silently
    is_mounted_path() {
      /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$1"
      return $?
    }
    
    # Path to the rclone-mount command from the profile
    RCLONE_MOUNT_CMD="${config.home.profileDirectory}/bin/rclone-mount"
    
    # Log startup - minimal output
    ${pkgs.coreutils}/bin/echo "Checking rclone mounts..."
    
    # Use the rclone-mount command for each mount point
    ${concatMapStringsSep "\n" (mount: ''
      if ! is_mounted_path "${mount.mountPoint}"; then
        ${pkgs.coreutils}/bin/echo "Mounting ${mount.remote} to ${mount.mountPoint}..."
        
        # Ensure mount point exists and is empty
        ${pkgs.coreutils}/bin/mkdir -p "${mount.mountPoint}"
        
        # Try to unmount if it's showing as busy
        diskutil unmount force "${mount.mountPoint}" 2>/dev/null || true
        
        # Use more robust mount options
        "$RCLONE_MOUNT_CMD" "${mount.remote}" "${mount.mountPoint}"
        
        # Give mount time to initialize
        ${pkgs.coreutils}/bin/sleep 3
        
        # Verify mount
        if is_mounted_path "${mount.mountPoint}"; then
          ${pkgs.coreutils}/bin/echo "Successfully mounted ${mount.remote}"
        else
          ${pkgs.coreutils}/bin/echo "Warning: Mount may have failed for ${mount.remote}"
        fi
      else
        # Mount already exists - no output needed
        :  # No-op
      fi
    '') mountService.mounts}
    
    # Done mounting all remotes
    ${pkgs.coreutils}/bin/echo "Done mounting rclone remotes"
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
          PATH = "${config.home.profileDirectory}/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          # Include HOME to ensure rclone finds its config
          HOME = "${config.home.homeDirectory}";
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
