{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone-launchd;

  # This module requires the rclone-mount service
  mountService = config.services.rclone-mount;

  # Create a script for the LaunchAgent that uses the rclone-mount script with better logging
  launchdScript = pkgs.writeShellScript "rclone-launchd-script" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    # Setup logging
    LOG_DIR="${config.home.homeDirectory}/nix-flakes/logs"
    LAUNCH_LOG="$LOG_DIR/rclone-launchd.log"
    ERROR_LOG="$LOG_DIR/rclone-launchd-error.log"
    
    # Create logs directory
    mkdir -p "$LOG_DIR"
    
    # Redirect output to logs
    exec >> "$LAUNCH_LOG" 2>> "$ERROR_LOG"
    
    # Log function for timestamps
    log() {
      echo "$(date '+%Y-%m-%d %H:%M:%S') - $*"
    }
    
    log "Starting rclone launchd service"
    
    # Function to check if a path is mounted
    is_mounted_path() {
      local mount_point="$1"
      if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$mount_point"; then
        log "Mount found: $mount_point"
        return 0
      else
        log "Mount not found: $mount_point"
        return 1
      fi
    }
    
    # Function to check if mount is accessible
    is_mount_accessible() {
      local mount_point="$1"
      if ls -la "$mount_point" > /dev/null 2>&1; then
        log "Mount is accessible: $mount_point"
        return 0
      else
        log "Mount is not accessible: $mount_point"
        return 1
      fi
    }
    
    # Path to the rclone-mount command from the profile
    RCLONE_MOUNT_CMD="${config.home.profileDirectory}/bin/rclone-mount"
    
    # Check rclone mount command exists
    if [ ! -x "$RCLONE_MOUNT_CMD" ]; then
      log "ERROR: rclone-mount command not found at $RCLONE_MOUNT_CMD"
      exit 1
    fi
    
    log "Found rclone-mount command: $RCLONE_MOUNT_CMD"
    
    # Check for rclone config
    if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
      log "ERROR: rclone config file not found"
      exit 1
    fi
    
    log "Found rclone config file"
    
    # Use the rclone-mount command for each mount point
    ${concatMapStringsSep "\n" (mount: ''
      log "Processing mount: ${mount.remote} -> ${mount.mountPoint}"
      
      if ! is_mounted_path "${mount.mountPoint}"; then
        log "Attempting to mount ${mount.remote} to ${mount.mountPoint}"
        
        # Use the mount script from rclone-mount module with output capture
        OUTPUT=$( { "$RCLONE_MOUNT_CMD" "${mount.remote}" "${mount.mountPoint}"; } 2>&1 )
        MOUNT_STATUS=$?
        
        if [ $MOUNT_STATUS -ne 0 ]; then
          log "ERROR: Mount command failed with status $MOUNT_STATUS"
          log "Output: $OUTPUT"
        else
          log "Mount command succeeded"
          
          # Verify mount is accessible
          if is_mounted_path "${mount.mountPoint}"; then
            if is_mount_accessible "${mount.mountPoint}"; then
              log "Successfully mounted and verified ${mount.remote}"
            else
              log "WARNING: Mount exists but is not accessible: ${mount.mountPoint}"
            fi
          else
            log "ERROR: Mount command succeeded but mount point is not mounted: ${mount.mountPoint}"
          fi
        fi
      else
        log "${mount.mountPoint} is already mounted, checking accessibility"
        is_mount_accessible "${mount.mountPoint}"
      fi
    '') mountService.mounts}
    
    log "rclone launchd service completed"
  '';

in
{
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
