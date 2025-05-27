{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone-mount;

  # Create a simple script for each mount operation
  mountScript = pkgs.writeShellScriptBin "rclone-mount" ''
    #!/usr/bin/env bash
    set -e
    REMOTE="$1"
    MOUNTPOINT="$2"
    LOG_DIR="${config.home.homeDirectory}/nix-flakes/logs"
    MOUNT_LOG="$LOG_DIR/rclone-mount.log"
    
    # Create logs directory
    mkdir -p "$LOG_DIR"
    
    # Log function for debugging
    log() {
      echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$MOUNT_LOG"
      echo "$*"
    }
    
    log "Starting mount operation for $REMOTE to $MOUNTPOINT"
    
    if [ -z "$REMOTE" ] || [ -z "$MOUNTPOINT" ]; then
      log "Error: Missing arguments. Usage: rclone-mount <remote:path> <mountpoint>"
      exit 1
    fi
    
    # Check if already mounted
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$MOUNTPOINT"; then
      log "$MOUNTPOINT is already mounted, exiting"
      exit 0
    fi
    
    # Ensure the mount point exists
    log "Creating mount point directory if needed"
    ${pkgs.coreutils}/bin/mkdir -p "$MOUNTPOINT" 2>> "$MOUNT_LOG" || {
      log "Error: Failed to create mount point: $MOUNTPOINT"
      exit 1
    }
    
    # Verify config file exists
    CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
    if [ ! -f "$CONFIG_FILE" ]; then
      log "Error: Rclone config file not found at $CONFIG_FILE"
      exit 1
    fi
    
    log "Found rclone config file: $CONFIG_FILE"
    
    # Check if remote exists in config
    REMOTE_NAME=$(echo $REMOTE | cut -d: -f1)
    if ! ${pkgs.rclone}/bin/rclone listremotes --config="$CONFIG_FILE" 2>> "$MOUNT_LOG" | grep -q "^$REMOTE_NAME:"; then
      log "Error: Remote '$REMOTE_NAME' not found in rclone config"
      log "Available remotes: $(${pkgs.rclone}/bin/rclone listremotes --config="$CONFIG_FILE" 2>> "$MOUNT_LOG")"
      exit 1
    fi
    
    log "Remote '$REMOTE_NAME' found in config"
    
    # Unmount first if needed
    log "Ensuring mount point is clean before mounting"
    if command -v diskutil >/dev/null 2>&1; then
      log "Using diskutil to unmount"
      diskutil unmount force "$MOUNTPOINT" >> "$MOUNT_LOG" 2>&1 || true
    else
      log "Using umount command"
      umount -f "$MOUNTPOINT" >> "$MOUNT_LOG" 2>&1 || true
    fi
    
    # Mount the remote filesystem with improved options
    log "Mounting $REMOTE to $MOUNTPOINT"
    ${pkgs.rclone}/bin/rclone mount "$REMOTE" "$MOUNTPOINT" \
      --vfs-cache-mode writes \
      --dir-cache-time 24h \
      --vfs-cache-max-size 2G \
      --vfs-write-back 5s \
      --buffer-size 64M \
      --transfers 4 \
      --allow-non-empty \
      --cache-dir="$HOME/.cache/rclone" \
      --log-level=INFO \
      --log-file="$MOUNT_LOG" \
      --attr-timeout=1s \
      --dir-perms=0700 \
      --file-perms=0600 \
      --config="$CONFIG_FILE" \
      --daemon \
      --rc \
      --rc-addr=127.0.0.1:0 >> "$MOUNT_LOG" 2>&1
      
    RESULT=$?
    if [ $RESULT -ne 0 ]; then
      log "Error: rclone mount command failed with exit code $RESULT"
      exit $RESULT
    fi
      
    # Wait a moment for mount to initialize
    log "Waiting for mount to initialize"
    ${pkgs.coreutils}/bin/sleep 2
    
    # Verify mount was successful
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$MOUNTPOINT"; then
      log "Successfully mounted $REMOTE to $MOUNTPOINT"
      # Try a basic file listing to confirm mount is working
      if ls -la "$MOUNTPOINT" > /dev/null 2>&1; then
        log "Mount is accessible and working"
      else
        log "Warning: Mount appears to be active but not accessible"
      fi
    else
      log "Error: Mount command completed but $MOUNTPOINT is not mounted"
      log "Check the log file at $MOUNT_LOG for details"
      exit 1
    fi
  '';

  unmountScript = pkgs.writeShellScriptBin "rclone-unmount" ''
    # Unmount helper script for rclone
    MOUNTPOINT="$1"
    
    if [ -z "$MOUNTPOINT" ]; then
      echo "Usage: rclone-unmount <mountpoint>"
      exit 1
    fi
    
    # Resolve to absolute path
    MOUNTPOINT=$(cd "$MOUNTPOINT" 2>/dev/null && pwd)
    if [ -z "$MOUNTPOINT" ]; then
      echo "Mount point does not exist: $1"
      exit 1
    fi
    
    # Check if mounted
    if ! /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$MOUNTPOINT"; then
      # Not mounted, silently exit
      exit 0
    fi
    
    # Kill rclone processes for this mount (silently)
    if [ -x "$(command -v pkill)" ]; then
      pkill -f "rclone.*mount.*$MOUNTPOINT" >/dev/null 2>&1 || true
    elif [ -x "$(command -v killall)" ]; then
      killall -9 "rclone" >/dev/null 2>&1 || true
    fi
    
    # Unmount the filesystem (silently)
    if command -v diskutil >/dev/null 2>&1; then
      diskutil unmount force "$MOUNTPOINT" >/dev/null 2>&1 || true
    else
      umount -f "$MOUNTPOINT" >/dev/null 2>&1 || true
      fusermount -u "$MOUNTPOINT" >/dev/null 2>&1 || true
    fi
  '';

  # Create a simple status script that shows mount info
  statusScript = pkgs.writeShellScriptBin "rclone-status" ''
    # Show mount paths
    MOUNTS=$(/sbin/mount | ${pkgs.gnugrep}/bin/grep -i rclone)
    
    if [ -z "$MOUNTS" ]; then
      echo "No rclone mounts found"
    else
      echo "$MOUNTS"
    fi
  '';

  listRemotesScript = pkgs.writeShellScriptBin "rclone-list-remotes" ''
    # List available rclone remotes
    echo "Available rclone remotes:"
    ${pkgs.rclone}/bin/rclone listremotes
  '';

  syncScript = pkgs.writeShellScriptBin "rclone-sync" ''
    # Force sync of rclone mounts
    RC_PORTS=""
    
    if [ -x "$(command -v ps)" ]; then
      RC_PORTS=$(${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep rclone | ${pkgs.gnugrep}/bin/grep -o "rc-addr=127.0.0.1:[0-9]*" | ${pkgs.gnused}/bin/sed 's/rc-addr=127.0.0.1://')
    fi
    
    if [ -z "$RC_PORTS" ]; then
      echo "No active rclone mounts with remote control ports found."
      exit 0
    fi
    
    for PORT in $RC_PORTS; do
      if nc -z 127.0.0.1 $PORT 2>/dev/null; then
        ${pkgs.rclone}/bin/rclone rc --rc-addr=127.0.0.1:$PORT vfs/refresh >/dev/null 2>&1
      fi
    done
    
    echo "Sync complete"
  '';
  
  # Create a debug script to analyze mount status and logs
  debugScript = pkgs.writeShellScriptBin "rclone-debug" ''
    #!/usr/bin/env bash
    # Script to analyze rclone mount logs for debugging
    
    set -e
    
    LOG_DIR="${config.home.homeDirectory}/nix-flakes/logs"
    MOUNT_LOG="$LOG_DIR/rclone-mount.log"
    ERROR_LOG="$LOG_DIR/rclone-errors.log"
    LAUNCHD_LOG="$LOG_DIR/rclone-launchd.log"
    LAUNCHD_ERROR_LOG="$LOG_DIR/rclone-launchd-error.log"
    
    # Function to print section headers
    print_header() {
      echo -e "\n===== $1 =====\n"
    }
    
    # Check if log directory exists
    if [ ! -d "$LOG_DIR" ]; then
      echo "Error: Log directory not found: $LOG_DIR"
      echo "Creating log directory..."
      mkdir -p "$LOG_DIR"
      exit 1
    fi
    
    # Display current mount status
    print_header "Current Mount Status"
    MOUNTS=$(/sbin/mount | grep -i rclone || echo "None found")
    if [ "$MOUNTS" = "None found" ]; then
      echo "No rclone mounts currently active"
    else
      echo "Active rclone mounts:"
      echo "$MOUNTS"
    fi
    
    # Display running rclone processes
    print_header "Running Rclone Processes"
    PROCESSES=$(ps aux | grep rclone | grep -v grep || echo "None running")
    if [ "$PROCESSES" = "None running" ]; then
      echo "No rclone processes currently running"
    else
      echo "Active rclone processes:"
      echo "$PROCESSES"
    fi
    
    # Display rclone mount log tail
    print_header "Recent Mount Log Entries"
    if [ -f "$MOUNT_LOG" ] && [ -s "$MOUNT_LOG" ]; then
      echo "Last 20 entries from $MOUNT_LOG:"
      tail -n 20 "$MOUNT_LOG"
    else
      echo "Mount log not found or empty: $MOUNT_LOG"
    fi
    
    # Display rclone error log tail
    print_header "Recent Error Log Entries"
    if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
      echo "Error log content from $ERROR_LOG:"
      cat "$ERROR_LOG"
    else
      echo "No error log found at $ERROR_LOG or it's empty - this is good!"
    fi
    
    # Display launchd log tail
    print_header "Recent Launchd Log Entries"
    if [ -f "$LAUNCHD_LOG" ] && [ -s "$LAUNCHD_LOG" ]; then
      echo "Last 20 entries from $LAUNCHD_LOG:"
      tail -n 20 "$LAUNCHD_LOG"
    else
      echo "Launchd log not found or empty: $LAUNCHD_LOG"
    fi
    
    # Display launchd error log tail
    print_header "Recent Launchd Error Log Entries"
    if [ -f "$LAUNCHD_ERROR_LOG" ] && [ -s "$LAUNCHD_ERROR_LOG" ]; then
      echo "Launchd error log content from $LAUNCHD_ERROR_LOG:"
      cat "$LAUNCHD_ERROR_LOG"
    else
      echo "No launchd error log found at $LAUNCHD_ERROR_LOG or it's empty - this is good!"
    fi
    
    # Display mount point accessibility
    print_header "Mount Point Accessibility Check"
    MOUNT_POINTS=$(/sbin/mount | grep -i rclone | awk '{print $3}')
    if [ -z "$MOUNT_POINTS" ]; then
      echo "No mount points to check"
    else
      for MOUNT_POINT in $MOUNT_POINTS; do
        echo -n "Checking $MOUNT_POINT... "
        if [ -d "$MOUNT_POINT" ]; then
          if ls -la "$MOUNT_POINT" >/dev/null 2>&1; then
            echo "Accessible"
            echo "Sample directory listing:"
            ls -la "$MOUNT_POINT" | head -n 5
          else
            echo "Not accessible!"
          fi
        else
          echo "Mount point does not exist!"
        fi
      done
    fi
    
    # Display system information
    print_header "System Information"
    echo "macOS Version: $(sw_vers -productVersion 2>/dev/null || echo "Unknown")"
    echo "Disk usage:"
    df -h | grep -i '/dev/'
    
    # Display rclone version
    print_header "Rclone Version"
    ${pkgs.rclone}/bin/rclone version
    
    # Provide some troubleshooting tips
    print_header "Troubleshooting Tips"
    echo "1. If mounts are not working, check your rclone configuration:"
    echo "   - Verify ~/.config/rclone/rclone.conf exists and is valid"
    echo "   - Run 'rclone listremotes' to confirm remotes are configured"
    echo ""
    echo "2. If logs show permissions issues:"
    echo "   - Check directory permissions with 'ls -la ~/mnt/rclone'"
    echo "   - Ensure your user has proper permissions"
    echo ""
    echo "3. For network issues:"
    echo "   - Verify network connectivity to the remote server"
    echo "   - Check for any firewall restrictions"
    echo ""
    echo "4. To manually mount:"
    echo "   - Run: rclone-mount [remote-name]:[path] [mount-point]"
    echo ""
    echo "5. To add more verbose logging:"
    echo "   - Edit modules/rclone/mount.nix to add --log-level=DEBUG"
    echo "   - Run 'home-manager switch' to apply changes"
  '';

in
{
  options.services.rclone-mount = {
    enable = mkEnableOption "rclone mount service";

    # Kubernetes config symlink settings
    kubeConfigPath = mkOption {
      type = types.str;
      default = "kubeconfig";
      description = "Path relative to the first mount where the kubeconfig file is stored";
    };
    
    kubeConfigDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.kube";
      description = "Directory where kubeconfig symlink is created";
    };
    
    kubeConfigName = mkOption {
      type = types.str;
      default = "config";
      description = "Name of the kubeconfig file to create in the kubeConfigDir";
    };

    mounts = mkOption {
      type = types.listOf (types.submodule {
        options = {
          remote = mkOption {
            type = types.str;
            description = "Remote path to mount (e.g., gdrive:backup)";
            example = "gdrive:backup";
          };

          mountPoint = mkOption {
            type = types.str;
            description = "Local directory where the remote will be mounted";
            example = "~/mnt/gdrive";
          };

          allowOther = mkOption {
            type = types.bool;
            default = false;
            description = "Allow other users to access the mount";
          };
        };
      });
      default = [ ];
      description = "List of rclone remotes to mount";
    };
  };

  config = mkIf cfg.enable {
    # Add the helper scripts to the user's path
    home.packages = [
      mountScript
      unmountScript
      statusScript
      listRemotesScript
      syncScript
      debugScript
      pkgs.rclone
      pkgs.netcat
      pkgs.procps
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.gnused
    ];

    # Create an activation script to mount remotes with detailed logging
    home.activation.mountRcloneRemotes = lib.hm.dag.entryAfter [ "decryptRcloneConfig" ] ''
      # Define log files
      LOG_DIR="$HOME/nix-flakes/logs"
      MOUNT_LOG="$LOG_DIR/rclone-mount.log"
      ERROR_LOG="$LOG_DIR/rclone-errors.log"
      
      # Create log directory if it doesn't exist
      mkdir -p "$LOG_DIR"
      
      # Log function
      log_message() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$MOUNT_LOG"
      }
      
      # Error log function
      log_error() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$ERROR_LOG"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$MOUNT_LOG"
        echo "ERROR: $1" >&2
      }
      
      log_message "Starting rclone mount activation"
      log_message "Log file: $MOUNT_LOG"
      log_message "Error log file: $ERROR_LOG"
      
      # Check if config file exists first
      CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
      
      # Only run the mount script if config file exists
      if [ -f "$CONFIG_FILE" ]; then
        log_message "Found rclone config file: $CONFIG_FILE"
        
        # Mount each configured remote with error handling
        ${concatMapStringsSep "\n" (mount: ''
          log_message "Attempting to mount ${mount.remote} to ${mount.mountPoint}"
          OUTPUT=$(${mountScript}/bin/rclone-mount "${mount.remote}" "${mount.mountPoint}" 2>&1)
          MOUNT_STATUS=$?
          
          if [ $MOUNT_STATUS -ne 0 ]; then
            log_error "Failed to mount ${mount.remote} to ${mount.mountPoint}. Exit code: $MOUNT_STATUS"
            log_error "Command output: $OUTPUT"
          else
            log_message "Mount command completed for ${mount.remote}"
            # Check if actually mounted
            if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "${mount.mountPoint}"; then
              log_message "Successfully mounted ${mount.remote} to ${mount.mountPoint}"
            else
              log_error "Mount command completed but ${mount.mountPoint} is not mounted"
            fi
          fi
        '') cfg.mounts}
      else
        log_error "Config file $CONFIG_FILE not found"
      fi
      
      log_message "Completed rclone mount activation"
    '';
    
    # Create an activation script to set up the kubeconfig symlink
    home.activation.linkKubeConfig = (
      let 
        # Use the first mount point by default
        firstMount = if (length cfg.mounts) > 0 then (elemAt cfg.mounts 0) else null;
        mountPoint = if firstMount != null then firstMount.mountPoint else "";
      in
      lib.hm.dag.entryAfter [ "mountRcloneRemotes" ] ''
        if [ "${mountPoint}" != "" ]; then
          SOURCE_PATH="${mountPoint}/${cfg.kubeConfigPath}"
          TARGET_DIR="${cfg.kubeConfigDir}"
          TARGET_FILE="$TARGET_DIR/${cfg.kubeConfigName}"
          
          if [ -e "$SOURCE_PATH" ]; then
            # Make sure target directory exists
            $DRY_RUN_CMD mkdir -p "$TARGET_DIR"
            
            # If target exists and is not a symlink, back it up
            if [ -f "$TARGET_FILE" ] && [ ! -L "$TARGET_FILE" ]; then
              echo "Backing up existing kubeconfig to $TARGET_FILE.backup"
              $DRY_RUN_CMD cp "$TARGET_FILE" "$TARGET_FILE.backup"
            fi
            
            # Create or update the symlink
            $DRY_RUN_CMD ln -sf "$SOURCE_PATH" "$TARGET_FILE"
            $DRY_RUN_CMD chmod 600 "$TARGET_FILE"
            # echo "Created kubeconfig symlink: $TARGET_FILE -> $SOURCE_PATH"
          else
            echo "Warning: Source path $SOURCE_PATH not found or rclone not mounted."
            echo "Will try again on next activation."
          fi
        else
          echo "Error: No mount point configured for kubeconfig symlink."
        fi
      ''
    );
    
    # Set environment variable for KUBECONFIG
    home.sessionVariables = {
      KUBECONFIG = "${cfg.kubeConfigDir}/${cfg.kubeConfigName}";
    };
  };
}
