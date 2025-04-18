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
    RCLONE_CONF="$HOME/.config/rclone/rclone.conf"
    if [ ! -f "$RCLONE_CONF" ]; then
      ${pkgs.coreutils}/bin/echo "No rclone configuration found at $RCLONE_CONF"
      ${pkgs.coreutils}/bin/echo "Checking if we need to decrypt the config..."
      
      # Try to trigger agenix decryption
      FLAKES_DIR="$HOME/nix-flakes"
      SECRET_FILE="$FLAKES_DIR/modules/agenix/rclone.conf.age"
      
      if [ -f "$SECRET_FILE" ]; then
        ${pkgs.coreutils}/bin/echo "Found encrypted config at $SECRET_FILE. Attempting to decrypt..."
        SSH_KEY="$HOME/.ssh/id_ed25519"
        
        if [ -f "$SSH_KEY" ]; then
          ${pkgs.agenix}/bin/agenix -d "$SECRET_FILE" -i "$SSH_KEY" > "$RCLONE_CONF" 2>/tmp/agenix-launch-error.log
        else
          ${pkgs.coreutils}/bin/echo "SSH key not found at $SSH_KEY, trying with default keys..."
          ${pkgs.agenix}/bin/agenix -d "$SECRET_FILE" > "$RCLONE_CONF" 2>/tmp/agenix-launch-error.log
        fi
        
        if [ -f "$RCLONE_CONF" ] && [ -s "$RCLONE_CONF" ]; then
          ${pkgs.coreutils}/bin/chmod 600 "$RCLONE_CONF"
          ${pkgs.coreutils}/bin/echo "Successfully decrypted rclone config"
        else
          ${pkgs.coreutils}/bin/echo "Failed to decrypt rclone config. See /tmp/agenix-launch-error.log for details."
          exit 1
        fi
      else
        ${pkgs.coreutils}/bin/echo "No encrypted config found at $SECRET_FILE. Exiting."
        exit 1
      fi
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
        
        # Ensure mount point exists and has proper permissions
        ${pkgs.coreutils}/bin/mkdir -p "${mount.mountPoint}"
        ${pkgs.coreutils}/bin/chmod 755 "${mount.mountPoint}"
        
        # Try to unmount if it's showing as busy
        if command -v diskutil >/dev/null 2>&1; then
          diskutil unmount force "${mount.mountPoint}" 2>/dev/null || true
        else
          umount -f "${mount.mountPoint}" 2>/dev/null || true
        fi
        
        # Use more robust mount options
        "$RCLONE_MOUNT_CMD" "${mount.remote}" "${mount.mountPoint}"
        
        # Give mount time to initialize
        ${pkgs.coreutils}/bin/sleep 3
        
        # Verify mount
        if is_mounted_path "${mount.mountPoint}"; then
          ${pkgs.coreutils}/bin/echo "Successfully mounted ${mount.remote}"
        else
          ${pkgs.coreutils}/bin/echo "Warning: Mount failed for ${mount.remote}"
          ${pkgs.coreutils}/bin/echo "Checking logs for errors..."
          
          # Check if log file exists
          if [ -f "/tmp/rclone-mount.log" ]; then
            ${pkgs.coreutils}/bin/tail -n 20 "/tmp/rclone-mount.log"
          fi
          
          # Test connection to remote
          ${pkgs.coreutils}/bin/echo "Testing connection to remote ${mount.remote}..."
          ${pkgs.rclone}/bin/rclone lsf "${mount.remote}" --max-depth 1 --quiet || {
            ${pkgs.coreutils}/bin/echo "Failed to list remote contents. Testing connection..."
            ${pkgs.rclone}/bin/rclone about "${mount.remote}" --json || ${pkgs.coreutils}/bin/echo "Cannot connect to remote ${mount.remote}"
          }
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
      # Check if config file exists first
      CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
      
      # Only run the mount script if config file exists
      if [ -f "$CONFIG_FILE" ]; then
        echo "Checking mounts after config update"
        $DRY_RUN_CMD ${launchdScript}
      else
        echo "Skipping rclone mount check - no config file"
      fi
    '';
  };
}
