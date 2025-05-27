{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone-mount;

  # Create a mount script with proper macOS utilities and error handling
  mountScript = pkgs.writeShellScriptBin "rclone-mount" ''
    #!/usr/bin/env bash
    set -e
    REMOTE="$1"
    MOUNTPOINT="$2"
    LOG_DIR="${config.home.homeDirectory}/nix-flakes/logs"
    MOUNT_LOG="$LOG_DIR/rclone-mount.log"
    ERROR_LOG="$LOG_DIR/rclone-errors.log"
    
    # Create logs directory
    mkdir -p "$LOG_DIR"
    
    # Log function for debugging
    log() {
      echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$MOUNT_LOG"
    }
    
    log_error() {
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $*" | tee -a "$ERROR_LOG" | tee -a "$MOUNT_LOG"
    }
    
    log "Starting mount operation for $REMOTE to $MOUNTPOINT"
    
    if [ -z "$REMOTE" ] || [ -z "$MOUNTPOINT" ]; then
      log_error "Missing arguments. Usage: rclone-mount <remote:path> <mountpoint>"
      exit 1
    fi
    
    # Expand tilde in mount point path
    MOUNTPOINT=$(eval echo "$MOUNTPOINT")
    
    # Check if already mounted
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $MOUNTPOINT "; then
      log "$MOUNTPOINT is already mounted"
      # Verify mount is working
      if ls -la "$MOUNTPOINT" >/dev/null 2>&1; then
        log "Mount is working correctly, exiting"
        exit 0
      else
        log "Mount exists but not accessible, will remount"
        # Continue to unmount and remount
      fi
    fi
    
    # Ensure the mount point exists
    log "Creating mount point directory if needed"
    ${pkgs.coreutils}/bin/mkdir -p "$MOUNTPOINT" 2>> "$ERROR_LOG" || {
      log_error "Failed to create mount point: $MOUNTPOINT"
      exit 1
    }
    
    # Verify config file exists
    CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
    if [ ! -f "$CONFIG_FILE" ]; then
      log_error "Rclone config file not found at $CONFIG_FILE"
      exit 1
    fi
    
    log "Found rclone config file: $CONFIG_FILE"
    
    # Check if remote exists in config
    REMOTE_NAME=$(echo $REMOTE | cut -d: -f1)
    if ! ${pkgs.rclone}/bin/rclone listremotes --config="$CONFIG_FILE" 2>> "$ERROR_LOG" | grep -q "^$REMOTE_NAME:"; then
      log_error "Remote '$REMOTE_NAME' not found in rclone config"
      log_error "Available remotes: $(${pkgs.rclone}/bin/rclone listremotes --config="$CONFIG_FILE" 2>> "$ERROR_LOG")"
      exit 1
    fi
    
    log "Remote '$REMOTE_NAME' found in config"
    
    # Clean unmount function for macOS
    cleanup_mount() {
      log "Ensuring mount point is clean before mounting"
      
      # Kill any existing rclone processes for this mount point
      ${pkgs.procps}/bin/pkill -f "rclone.*mount.*$MOUNTPOINT" 2>/dev/null || true
      
      # Wait a moment for processes to die
      sleep 1
      
      # Try diskutil first (macOS native)
      if command -v diskutil >/dev/null 2>&1; then
        log "Using diskutil to unmount"
        diskutil unmount force "$MOUNTPOINT" >> "$MOUNT_LOG" 2>&1 || true
      fi
      
      # Also try umount if available (should be provided by system)
      if command -v umount >/dev/null 2>&1; then
        log "Using umount command"
        umount "$MOUNTPOINT" >> "$MOUNT_LOG" 2>&1 || true
      fi
      
      # Give time for cleanup
      sleep 2
    }
    
    # Perform cleanup
    cleanup_mount
    
    # Create cache directory
    CACHE_DIR="$HOME/.cache/rclone"
    mkdir -p "$CACHE_DIR"
    
    # Mount the remote filesystem with optimized options for macOS
    log "Mounting $REMOTE to $MOUNTPOINT"
    ${pkgs.rclone}/bin/rclone mount "$REMOTE" "$MOUNTPOINT" \
      --config="$CONFIG_FILE" \
      --vfs-cache-mode writes \
      --vfs-cache-max-age 24h \
      --vfs-cache-max-size 2G \
      --vfs-write-back 5s \
      --buffer-size 64M \
      --transfers 4 \
      --checkers 8 \
      --low-level-retries 10 \
      --retries 3 \
      --timeout 60s \
      --contimeout 60s \
      --allow-non-empty \
      --cache-dir="$CACHE_DIR" \
      --log-level=INFO \
      --log-file="$MOUNT_LOG" \
      --attr-timeout=1s \
      --dir-cache-time=24h \
      --poll-interval=15s \
      --daemon \
      --rc \
      --rc-addr=127.0.0.1:0 \
      --rc-no-auth \
      --volname="rclone-$REMOTE_NAME" >> "$MOUNT_LOG" 2>> "$ERROR_LOG" &
      
    RCLONE_PID=$!
    log "Started rclone process with PID: $RCLONE_PID"
    
    # Wait for mount to initialize
    log "Waiting for mount to initialize"
    WAIT_COUNT=0
    MAX_WAIT=30
    
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
      if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $MOUNTPOINT "; then
        log "Mount detected, checking accessibility"
        if ls -la "$MOUNTPOINT" >/dev/null 2>&1; then
          log "Successfully mounted $REMOTE to $MOUNTPOINT"
          log "Mount is accessible and working"
          exit 0
        else
          log "Mount detected but not yet accessible, waiting..."
        fi
      fi
      
      # Check if rclone process is still running
      if ! kill -0 $RCLONE_PID 2>/dev/null; then
        log_error "rclone process died unexpectedly"
        break
      fi
      
      sleep 1
      WAIT_COUNT=$((WAIT_COUNT + 1))
    done
    
    # If we get here, mount failed
    log_error "Mount failed or timed out after $MAX_WAIT seconds"
    log_error "Killing rclone process $RCLONE_PID"
    kill $RCLONE_PID 2>/dev/null || true
    
    # Try to show recent errors
    if [ -f "$ERROR_LOG" ]; then
      log_error "Recent errors:"
      tail -10 "$ERROR_LOG" 2>/dev/null || true
    fi
    
    exit 1
  '';

  # Enhanced unmount script
  unmountScript = pkgs.writeShellScriptBin "rclone-unmount" ''
    #!/usr/bin/env bash
    MOUNTPOINT="$1"
    
    if [ -z "$MOUNTPOINT" ]; then
      echo "Usage: rclone-unmount <mountpoint>"
      exit 1
    fi
    
    # Expand tilde in mount point path
    MOUNTPOINT=$(eval echo "$MOUNTPOINT")
    
    # Resolve to absolute path if it exists
    if [ -d "$MOUNTPOINT" ]; then
      MOUNTPOINT=$(cd "$MOUNTPOINT" 2>/dev/null && pwd)
    fi
    
    if [ -z "$MOUNTPOINT" ]; then
      echo "Mount point does not exist: $1"
      exit 1
    fi
    
    echo "Unmounting: $MOUNTPOINT"
    
    # Check if mounted
    if ! /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $MOUNTPOINT "; then
      echo "Not mounted: $MOUNTPOINT"
      exit 0
    fi
    
    # Kill rclone processes for this mount
    echo "Stopping rclone processes..."
    ${pkgs.procps}/bin/pkill -f "rclone.*mount.*$MOUNTPOINT" >/dev/null 2>&1 || true
    
    # Wait for processes to exit
    sleep 2
    
    # Force kill if still running
    ${pkgs.procps}/bin/pkill -9 -f "rclone.*mount.*$MOUNTPOINT" >/dev/null 2>&1 || true
    
    # Unmount using diskutil (macOS native)
    if command -v diskutil >/dev/null 2>&1; then
      echo "Using diskutil to unmount..."
      diskutil unmount force "$MOUNTPOINT" 2>/dev/null || true
    fi
    
    # Also try system umount if available
    if command -v umount >/dev/null 2>&1; then
      echo "Using umount..."
      umount "$MOUNTPOINT" 2>/dev/null || true
    fi
    
    # Give time for cleanup
    sleep 1
    
    # Verify unmount
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $MOUNTPOINT "; then
      echo "WARNING: Mount point may still be active: $MOUNTPOINT"
      exit 1
    else
      echo "Successfully unmounted: $MOUNTPOINT"
      exit 0
    fi
  '';

  # Create a simple status script that shows mount info
  statusScript = pkgs.writeShellScriptBin "rclone-status" ''
    echo "=== Rclone Mount Status ==="
    MOUNTS=$(/sbin/mount | ${pkgs.gnugrep}/bin/grep -E '(rclone|osxfuse|macfuse)')
    
    if [ -z "$MOUNTS" ]; then
      echo "No rclone mounts found"
    else
      echo "Active rclone mounts:"
      echo "$MOUNTS"
      echo ""
      echo "=== Process Status ==="
      ${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep rclone | ${pkgs.gnugrep}/bin/grep -v grep || echo "No rclone processes running"
    fi
  '';

  listRemotesScript = pkgs.writeShellScriptBin "rclone-list-remotes" ''
    CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
    if [ -f "$CONFIG_FILE" ]; then
      echo "Available rclone remotes:"
      ${pkgs.rclone}/bin/rclone listremotes --config="$CONFIG_FILE"
    else
      echo "Rclone config file not found at $CONFIG_FILE"
      exit 1
    fi
  '';

  syncScript = pkgs.writeShellScriptBin "rclone-sync" ''
    # Force sync of rclone mounts via remote control
    echo "Syncing rclone VFS caches..."
    
    RC_PORTS=""
    if [ -x "$(command -v ps)" ]; then
      RC_PORTS=$(${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep rclone | ${pkgs.gnugrep}/bin/grep -o "rc-addr=127.0.0.1:[0-9]*" | ${pkgs.gnused}/bin/sed 's/rc-addr=127.0.0.1://' || true)
    fi
    
    if [ -z "$RC_PORTS" ]; then
      echo "No active rclone mounts with remote control found."
      exit 0
    fi
    
    SYNC_COUNT=0
    for PORT in $RC_PORTS; do
      if ${pkgs.netcat}/bin/nc -z 127.0.0.1 $PORT 2>/dev/null; then
        echo "Syncing mount on port $PORT..."
        ${pkgs.rclone}/bin/rclone rc --rc-addr=127.0.0.1:$PORT vfs/refresh >/dev/null 2>&1 && SYNC_COUNT=$((SYNC_COUNT + 1))
      fi
    done
    
    echo "Synced $SYNC_COUNT mount(s)"
  '';

  # Enhanced debug script
  debugScript = pkgs.writeShellScriptBin "rclone-debug" ''
    #!/usr/bin/env bash
    
    LOG_DIR="${config.home.homeDirectory}/nix-flakes/logs"
    MOUNT_LOG="$LOG_DIR/rclone-mount.log"
    ERROR_LOG="$LOG_DIR/rclone-errors.log"
    
    # Function to print section headers
    print_header() {
      echo -e "\n===== $1 =====\n"
    }
    
    print_header "System Information"
    echo "macOS Version: $(sw_vers -productVersion 2>/dev/null || echo "Unknown")"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    
    print_header "Available System Commands"
    echo "diskutil: $(command -v diskutil || echo "Not found")"
    echo "umount: $(command -v umount || echo "Not found")"
    echo "mount: $(command -v mount || echo "Not found")"
    
    print_header "macFUSE Status"
    if [ -d "/Library/Frameworks/macFUSE.framework" ]; then
      echo "macFUSE framework found"
      if [ -f "/Library/Frameworks/macFUSE.framework/Resources/Info.plist" ]; then
        VERSION=$(defaults read /Library/Frameworks/macFUSE.framework/Resources/Info.plist CFBundleShortVersionString 2>/dev/null || echo "Unknown")
        echo "macFUSE version: $VERSION"
      fi
    else
      echo "⚠️  macFUSE framework NOT found"
      echo "   Install from: https://osxfuse.github.io/"
    fi
    
    print_header "Current Mount Status"
    MOUNTS=$(/sbin/mount | grep -E '(rclone|osxfuse|macfuse)' || echo "None found")
    echo "$MOUNTS"
    
    print_header "Running Rclone Processes"
    PROCESSES=$(${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep rclone | ${pkgs.gnugrep}/bin/grep -v grep || echo "None running")
    echo "$PROCESSES"
    
    print_header "Rclone Configuration"
    CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
    if [ -f "$CONFIG_FILE" ]; then
      echo "Config file exists: $CONFIG_FILE"
      echo "Size: $(ls -lah "$CONFIG_FILE" | awk '{print $5}')"
      echo "Modified: $(ls -lah "$CONFIG_FILE" | awk '{print $6, $7, $8}')"
      echo "Remotes:"
      ${pkgs.rclone}/bin/rclone listremotes --config="$CONFIG_FILE" 2>/dev/null || echo "Error reading remotes"
    else
      echo "⚠️  Config file NOT found: $CONFIG_FILE"
    fi
    
    print_header "Mount Points"
    ${concatMapStringsSep "\n" (mount: ''
      MOUNT_POINT="${mount.mountPoint}"
      # Expand tilde
      MOUNT_POINT=$(eval echo "$MOUNT_POINT")
      echo "Checking: ${mount.remote} -> $MOUNT_POINT"
      if [ -d "$MOUNT_POINT" ]; then
        echo "  Directory exists: ✓"
        if ls -la "$MOUNT_POINT" >/dev/null 2>&1; then
          FILE_COUNT=$(ls -1 "$MOUNT_POINT" 2>/dev/null | wc -l | tr -d ' ')
          echo "  Accessible: ✓ ($FILE_COUNT items)"
        else
          echo "  Accessible: ✗"
        fi
        if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $MOUNT_POINT "; then
          echo "  Mounted: ✓"
        else
          echo "  Mounted: ✗"
        fi
      else
        echo "  Directory exists: ✗"
      fi
    '') cfg.mounts}
    
    print_header "Recent Log Entries"
    if [ -f "$MOUNT_LOG" ] && [ -s "$MOUNT_LOG" ]; then
      echo "Last 10 entries from mount log:"
      tail -n 10 "$MOUNT_LOG"
    else
      echo "No mount log found or empty"
    fi
    
    if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
      echo -e "\nRecent errors:"
      tail -n 10 "$ERROR_LOG"
    fi
    
    print_header "Troubleshooting Commands"
    echo "Manual mount: rclone-mount <remote:path> <mount-point>"
    echo "Unmount: rclone-unmount <mount-point>"
    echo "Status: rclone-status"
    echo "Sync VFS: rclone-sync"
    echo "List remotes: rclone-list-remotes"
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
    # Add required packages including macFUSE stubs for build time
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
      # Add macFUSE stubs for build compatibility
      pkgs.macfuse-stubs
    ];

    # Create an activation script to mount remotes with improved error handling
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
      }
      
      log_message "Starting rclone mount activation"
      log_message "Log file: $MOUNT_LOG"
      log_message "Error log file: $ERROR_LOG"
      
      # Check for macFUSE installation
      if [ ! -d "/Library/Frameworks/macFUSE.framework" ]; then
        log_error "macFUSE framework not found. Please install macFUSE from https://osxfuse.github.io/"
        log_error "rclone mounting requires macFUSE to be installed on macOS"
        exit 0  # Don't fail the entire activation
      fi
      
      # Check if config file exists first
      CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
      
      if [ -f "$CONFIG_FILE" ]; then
        log_message "Found rclone config file: $CONFIG_FILE"
        
        # Mount each configured remote with better error handling
        ${concatMapStringsSep "\n" (mount: ''
          log_message "Processing mount: ${mount.remote} -> ${mount.mountPoint}"
          
          # Expand tilde in mount point
          EXPANDED_MOUNT=$(eval echo "${mount.mountPoint}")
          
          # Check if already mounted and working
          if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $EXPANDED_MOUNT "; then
            if ls -la "$EXPANDED_MOUNT" >/dev/null 2>&1; then
              log_message "${mount.remote} already mounted and accessible at $EXPANDED_MOUNT"
              continue
            else
              log_message "${mount.remote} mounted but not accessible, will remount"
            fi
          fi
          
          # Attempt to mount using the improved script
          if ${mountScript}/bin/rclone-mount "${mount.remote}" "${mount.mountPoint}" >> "$MOUNT_LOG" 2>> "$ERROR_LOG"; then
            log_message "Successfully set up mount for ${mount.remote}"
          else
            log_error "Failed to mount ${mount.remote} to ${mount.mountPoint}"
            log_error "Check logs for details or run 'rclone-debug' for diagnostics"
          fi
        '') cfg.mounts}
      else
        log_error "Config file $CONFIG_FILE not found"
        log_error "Ensure rclone service is enabled and secrets are properly decrypted"
      fi
      
      log_message "Completed rclone mount activation"
    '';

    # Create an activation script to set up the kubeconfig symlink
    home.activation.linkKubeConfig =
      let
        # Use the first mount point by default
        firstMount = if (length cfg.mounts) > 0 then (elemAt cfg.mounts 0) else null;
        mountPoint = if firstMount != null then firstMount.mountPoint else "";
      in
      lib.hm.dag.entryAfter [ "mountRcloneRemotes" ] ''
        if [ "${mountPoint}" != "" ]; then
          # Expand tilde in mount point
          EXPANDED_MOUNT=$(eval echo "${mountPoint}")
          SOURCE_PATH="$EXPANDED_MOUNT/${cfg.kubeConfigPath}"
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
            $DRY_RUN_CMD chmod 600 "$TARGET_FILE" 2>/dev/null || true
          else
            echo "Note: kubeconfig source $SOURCE_PATH not found"
            echo "Will be available after rclone mount succeeds"
          fi
        fi
      '';

    # Set environment variable for KUBECONFIG
    home.sessionVariables = {
      KUBECONFIG = "${cfg.kubeConfigDir}/${cfg.kubeConfigName}";
    };
  };
}
