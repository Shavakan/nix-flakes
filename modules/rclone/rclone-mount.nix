{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone-mount;
  
  # Create a simple script for each mount operation
  mountScript = pkgs.writeShellScriptBin "rclone-mount" ''
    #!/usr/bin/env bash
    # Mount helper script for rclone
    REMOTE="$1"
    MOUNTPOINT="$2"
    
    if [ -z "$REMOTE" ] || [ -z "$MOUNTPOINT" ]; then
      echo "Usage: rclone-mount <remote:path> <mountpoint>"
      echo "Example: rclone-mount gdrive:backup ~/mnt/gdrive"
      exit 1
    fi
    
    # Check if already mounted
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$MOUNTPOINT"; then
      echo "$MOUNTPOINT is already mounted"
      exit 0
    fi
    
    # Ensure the mount point exists
    ${pkgs.coreutils}/bin/mkdir -p "$MOUNTPOINT"
    
    # Prepare to mount the remote filesystem
    # Try to unmount first if resource busy error tends to happen
    diskutil unmount force "$MOUNTPOINT" 2>/dev/null || true
    
    # Ensure mount point exists and is empty
    ${pkgs.coreutils}/bin/mkdir -p "$MOUNTPOINT"
    
    # Mount the remote filesystem with improved options
    # Using daemon mode with allow-non-empty to handle existing directories
    ${pkgs.rclone}/bin/rclone mount "$REMOTE" "$MOUNTPOINT" \
      --vfs-cache-mode writes \
      --dir-cache-time 24h \
      --vfs-cache-max-size 2G \
      --vfs-write-back 5s \
      --buffer-size 64M \
      --transfers 4 \
      --allow-non-empty \
      --cache-dir="$HOME/.cache/rclone" \
      --log-level=ERROR \
      --log-file="/tmp/rclone-mount.log" \
      --attr-timeout=1s \
      --dir-perms=0700 \
      --file-perms=0600 \
      --config="$HOME/.config/rclone/rclone.conf" \
      --daemon
      
    # Wait a moment for mount to initialize
    ${pkgs.coreutils}/bin/sleep 2
      
    # Verify the mount was successful
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$MOUNTPOINT"; then
      echo "Mounted $REMOTE at $MOUNTPOINT"
    else
      echo "Mount failed: $MOUNTPOINT"
    fi
  '';
  
  unmountScript = pkgs.writeShellScriptBin "rclone-unmount" ''
    # Unmount helper script for rclone
    MOUNTPOINT="$1"
    
    if [ -z "$MOUNTPOINT" ]; then
      echo "Usage: rclone-unmount <mountpoint>"
      echo "Example: rclone-unmount ~/mnt/rclone"
      exit 1
    fi
    
    # Resolve to absolute path
    MOUNTPOINT=$(cd "$MOUNTPOINT" 2>/dev/null && pwd)
    if [ -z "$MOUNTPOINT" ]; then
      echo "Mount point does not exist: $1"
      exit 1
    fi
    
    # Check if mounted (macOS friendly approach)
    if ! /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$MOUNTPOINT"; then
      echo "No filesystem mounted at $MOUNTPOINT"
      exit 0
    fi
    
    # Kill rclone processes for this mount - use pkill or killall depending on what's available
    if [ -x "$(command -v pkill)" ]; then
      pkill -f "rclone.*mount.*$MOUNTPOINT" || true
    elif [ -x "$(command -v killall)" ]; then
      killall -9 "rclone" || true
    else
      echo "Warning: Neither pkill nor killall commands found, may not properly terminate rclone"
    fi
    ${pkgs.coreutils}/bin/sleep 1
    
    # Unmount the filesystem
    diskutil unmount force "$MOUNTPOINT" 2>/dev/null || true
    
    echo "Unmounted $MOUNTPOINT"
  '';
  
  # Create a simple status script that shows mount info without being verbose
  statusScript = pkgs.writeShellScriptBin "rclone-status" ''
    # Show only mount paths
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
    # Use simple approach to find RC ports
    RC_PORTS=""
    
    if [ -x "$(command -v ps)" ]; then
      RC_PORTS=$(${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep rclone | ${pkgs.gnugrep}/bin/grep -o "rc-addr=127.0.0.1:[0-9]*" | ${pkgs.gnused}/bin/sed 's/rc-addr=127.0.0.1://')
    fi
    
    if [ -z "$RC_PORTS" ]; then
      echo "No active rclone mounts with remote control ports found."
      exit 1
    fi
    
    for PORT in $RC_PORTS; do
      if nc -z 127.0.0.1 $PORT 2>/dev/null; then
        echo "Forcing sync of rclone mount using port $PORT..."
        ${pkgs.rclone}/bin/rclone rc --rc-addr=127.0.0.1:$PORT vfs/refresh
        echo "Sync complete for port $PORT"
      fi
    done
  '';
  
  # Add a script for secure copy of confidential files
  secureTransferScript = pkgs.writeShellScriptBin "rclone-secure-copy" ''
    #!/usr/bin/env bash
    # Script for securely copying confidential files with rclone
    
    # Show usage information
    function show_usage {
      echo "Usage: rclone-secure-copy [options] <source> <destination>"
      echo ""
      echo "Options:"
      echo "  -e, --encrypt    Enable encryption (for uploads)"
      echo "  -d, --decrypt    Enable decryption (for downloads)"
      echo "  -p, --progress   Show progress during transfer"
      echo "  -h, --help       Show this help message"
      echo ""
      echo "Examples:"
      echo "  rclone-secure-copy --encrypt ~/Documents/secret.pdf remote:confidential/"
      echo "  rclone-secure-copy --decrypt remote:confidential/secret.pdf.enc ~/Downloads/"
      exit 1
    }
    
    # Parse arguments
    ENCRYPT=false
    DECRYPT=false
    PROGRESS=false
    
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -e|--encrypt)
          ENCRYPT=true
          shift
          ;;
        -d|--decrypt)
          DECRYPT=true
          shift
          ;;
        -p|--progress)
          PROGRESS=true
          shift
          ;;
        -h|--help)
          show_usage
          ;;
        -*)
          echo "Unknown option: $1"
          show_usage
          ;;
        *)
          break
          ;;
      esac
    done
    
    # Check for source and destination
    if [ $# -ne 2 ]; then
      echo "Error: Source and destination must be specified"
      show_usage
    fi
    
    SOURCE="$1"
    DEST="$2"
    
    # Prepare rclone options
    RCLONE_OPTS="--transfers 4 --checkers 8 --cache-chunk-no-memory"
    
    if [ "$PROGRESS" = true ]; then
      RCLONE_OPTS="$RCLONE_OPTS --progress"
    else
      RCLONE_OPTS="$RCLONE_OPTS --quiet"
    fi
    
    # Add config file path
    RCLONE_OPTS="$RCLONE_OPTS --config=$HOME/.config/rclone/rclone.conf"
    
    # Handle encryption/decryption if needed
    if [ "$ENCRYPT" = true ] && [ "$DECRYPT" = true ]; then
      echo "Error: Cannot use both --encrypt and --decrypt together"
      exit 1
    elif [ "$ENCRYPT" = true ]; then
      echo "Encrypting and copying file..."
      # Create a temporary encrypted file
      TEMP_FILE="$(mktemp)"
      trap "rm -f '$TEMP_FILE'" EXIT
      
      # Encrypt the file with GPG
      gpg --output "$TEMP_FILE" --symmetric --cipher-algo AES256 "$SOURCE"
      if [ $? -ne 0 ]; then
        echo "Error: Encryption failed"
        exit 1
      fi
      
      # Copy the encrypted file
      ${pkgs.rclone}/bin/rclone copy $RCLONE_OPTS "$TEMP_FILE" "$DEST"
      if [ $? -eq 0 ]; then
        echo "File securely encrypted and copied to $DEST"
      else
        echo "Error: Failed to copy encrypted file"
        exit 1
      fi
    elif [ "$DECRYPT" = true ]; then
      echo "Downloading and decrypting file..."
      # Create a temporary file for the encrypted content
      TEMP_FILE="$(mktemp)"
      trap "rm -f '$TEMP_FILE'" EXIT
      
      # Download the encrypted file
      ${pkgs.rclone}/bin/rclone copy $RCLONE_OPTS "$SOURCE" "$(dirname "$TEMP_FILE")/"
      if [ $? -ne 0 ]; then
        echo "Error: Failed to download encrypted file"
        exit 1
      fi
      
      # Decrypt the file
      gpg --output "$DEST" --decrypt "$TEMP_FILE"
      if [ $? -eq 0 ]; then
        echo "File successfully downloaded and decrypted to $DEST"
      else
        echo "Error: Decryption failed"
        exit 1
      fi
    else
      # Standard copy without encryption
      echo "Copying file securely..."
      ${pkgs.rclone}/bin/rclone copy $RCLONE_OPTS "$SOURCE" "$DEST"
      if [ $? -eq 0 ]; then
        echo "File successfully copied to $DEST"
      else
        echo "Error: Failed to copy file"
        exit 1
      fi
    fi
  '';
  
  # Optional S3-specific tools - not included by default
  _s3MountScript = pkgs.writeShellScriptBin "_rclone-mount-s3" ''
    echo "S3 mounting functionality not enabled by default"
    echo "Edit your mount.nix file to include S3-specific tools if needed"
  '';
  
  _s3TestScript = pkgs.writeShellScriptBin "_rclone-test-s3" ''
    echo "S3 testing functionality not enabled by default"
    echo "Edit your mount.nix file to include S3-specific tools if needed"
  '';
  
  # Add a debugging tool for rclone mounts
  debugScript = pkgs.writeShellScriptBin "rclone-debug" ''
    #!/usr/bin/env bash
    # Debugging helper for rclone mounts
    MOUNTPOINT="$1"
    
    if [ -z "$MOUNTPOINT" ]; then
      echo "Usage: rclone-debug <mountpoint>"
      echo "Example: rclone-debug ~/mnt/rclone"
      exit 1
    fi
    
    # Resolve to absolute path if it exists
    if [ -d "$MOUNTPOINT" ]; then
      MOUNTPOINT=$(cd "$MOUNTPOINT" 2>/dev/null && pwd)
    fi
    
    echo "===== RCLONE MOUNT DEBUGGING ====="
    echo "Checking mount point: $MOUNTPOINT"
    
    echo "\n=== Mount Status ==="
    /sbin/mount | ${pkgs.gnugrep}/bin/grep -i "$MOUNTPOINT" || echo "Not mounted"
    
    echo "\n=== Process Status ==="
    if [ -x "$(command -v ps)" ]; then
      ${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep -i "rclone.*$MOUNTPOINT" | ${pkgs.gnugrep}/bin/grep -v grep || echo "No rclone process found for $MOUNTPOINT"
    else
      echo "ps command not available - cannot show process details"
    fi
    
    echo "\n=== Recent Mount Logs (all instances) ==="
    LOG_FILES=$(ls -t /tmp/rclone-mount*.log 2>/dev/null)
    if [ -n "$LOG_FILES" ]; then
      for LOG_FILE in $LOG_FILES; do
        echo "From $LOG_FILE:"
        tail -n 10 "$LOG_FILE"
        echo "-----------------------------------------"
      done
    else
      echo "No log files found in /tmp/rclone-mount*.log"
    fi
    
    # Try to get the remote from command line or ps output
    REMOTE=""
    if [ -x "$(command -v ps)" ]; then
      REMOTE=$(${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep -i "rclone.*$MOUNTPOINT" | ${pkgs.gnugrep}/bin/grep -v grep | ${pkgs.gnused}/bin/sed -n 's/.*mount \([^ ]*\) .*/\1/p' | head -1)
    fi
    
    if [ -n "$REMOTE" ]; then
      echo "\n=== Remote Information ==="
      echo "Remote: $REMOTE"
      echo "Testing connection to remote..."
      ${pkgs.rclone}/bin/rclone about "$REMOTE" --json || echo "Failed to connect to remote"
      
      echo "\n=== Listing Remote Contents ==="
      ${pkgs.rclone}/bin/rclone lsf "$REMOTE" --max-depth 1 || echo "Failed to list remote contents"
    else
      echo "\n=== Remote Information ==="
      echo "Could not determine remote from process list"
      echo "Available remotes:"
      ${pkgs.rclone}/bin/rclone listremotes
    fi
    
    echo "\n=== Network Connectivity ==="
    if [ -x "$(command -v ping)" ]; then
      ping -c 3 8.8.8.8 || echo "Cannot ping external network (8.8.8.8)"
    else
      echo "ping command not found"
    fi
    
    echo "\n=== RC Status ==="
    RC_PORTS=""
    
    if [ -x "$(command -v ps)" ]; then
      RC_PORTS=$(${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep rclone | ${pkgs.gnugrep}/bin/grep -o "rc-addr=127.0.0.1:[0-9]*" | ${pkgs.gnused}/bin/sed 's/rc-addr=127.0.0.1://')
    fi
    
    if [ -n "$RC_PORTS" ]; then
      echo "Found active remote control port(s): $RC_PORTS"
      for PORT in $RC_PORTS; do
        if nc -z 127.0.0.1 $PORT 2>/dev/null; then
          echo "Remote control is running on port $PORT"
          ${pkgs.rclone}/bin/rclone rc --rc-addr=127.0.0.1:$PORT core/stats || echo "Failed to get stats from RC server on port $PORT"
        else
          echo "Port $PORT is configured but not responding"
        fi
      done
    else
      echo "No remote control servers found running"
    fi
    
    echo "\n===== DEBUGGING COMPLETE ====="
  '';
  
in {
  options.services.rclone-mount = {
    enable = mkEnableOption "rclone mount service";
    
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
      default = [];
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
      secureTransferScript
      debugScript
      pkgs.rclone
      pkgs.netcat
      pkgs.procps   # For ps and pgrep commands
      pkgs.gnugrep  # For grep command
      pkgs.gnupg    # Required for encryption/decryption
      pkgs.coreutils # Basic utilities (mkdir, sleep, echo, date)
      pkgs.gnused   # For sed used in debug script
    ];
  };
}
