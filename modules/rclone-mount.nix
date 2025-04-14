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
    # Mount the remote filesystem with improved options for confidential files
    nohup ${pkgs.rclone}/bin/rclone mount "$REMOTE" "$MOUNTPOINT" \
      --vfs-cache-mode full \
      --dir-cache-time 24h \
      --vfs-cache-max-size 2G \
      --vfs-write-back 5s \
      --vfs-read-ahead 128M \
      --buffer-size 64M \
      --transfers 4 \
      --rc \
      --rc-addr=127.0.0.1:5572 \
      --rc-no-auth \
      --allow-non-empty \
      --cache-dir="$HOME/.cache/rclone" \
      --log-level=INFO \
      --log-file="/tmp/rclone-mount.log" \
      --umask=077 \
      --attr-timeout=1s \
      --dir-perms=0700 \
      --file-perms=0600 \
      --config="$HOME/.config/rclone/rclone.conf" \
      > /dev/null 2>&1 &
      
    # Wait a moment for mount to initialize
    ${pkgs.coreutils}/bin/sleep 2
      
    # Verify the mount was successful
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$MOUNTPOINT"; then
      echo "Mounted $REMOTE at $MOUNTPOINT"
    else
      echo "WARNING: Mount command completed but $MOUNTPOINT doesn't appear to be mounted"
      echo "Check /tmp/rclone-mount.log for errors"
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
  
  statusScript = pkgs.writeShellScriptBin "rclone-status" ''
    # Show status of rclone mounts
    echo "Current rclone mounts:"
    /sbin/mount | ${pkgs.gnugrep}/bin/grep -i rclone
    
    # Show active rclone processes
    echo -e "\nActive rclone processes:"
    ${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep -i rclone | ${pkgs.gnugrep}/bin/grep -v grep
  '';
  
  listRemotesScript = pkgs.writeShellScriptBin "rclone-list-remotes" ''
    # List available rclone remotes
    echo "Available rclone remotes:"
    ${pkgs.rclone}/bin/rclone listremotes
  '';
  
  syncScript = pkgs.writeShellScriptBin "rclone-sync" ''
    # Force sync of rclone mounts
    if nc -z 127.0.0.1 5572 2>/dev/null; then
      echo "Forcing sync of all rclone mounts..."
      ${pkgs.rclone}/bin/rclone rc --rc-addr=127.0.0.1:5572 vfs/refresh
      echo "Sync complete"
    else
      echo "Remote control server is not running. Mount may not be active."
      exit 1
    fi
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
      ps aux | ${pkgs.gnugrep}/bin/grep -i "rclone.*$MOUNTPOINT" | ${pkgs.gnugrep}/bin/grep -v grep || echo "No rclone process found"
    else
      echo "ps command not found"
    fi
    
    echo "\n=== Recent Mount Log (last 20 lines) ==="
    if [ -f "/tmp/rclone-mount.log" ]; then
      tail -n 20 /tmp/rclone-mount.log
    else
      echo "No log file found at /tmp/rclone-mount.log"
    fi
    
    # Try to get the remote from command line or ps output
    REMOTE=""
    if [ -x "$(command -v ps)" ]; then
      REMOTE=$(ps aux | ${pkgs.gnugrep}/bin/grep -i "rclone.*$MOUNTPOINT" | ${pkgs.gnugrep}/bin/grep -v grep | ${pkgs.gnused}/bin/sed -n 's/.*mount \([^ ]*\) .*/\1/p')
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
    if nc -z 127.0.0.1 5572 2>/dev/null; then
      echo "Remote control is running"
      ${pkgs.rclone}/bin/rclone rc --rc-addr=127.0.0.1:5572 core/stats || echo "Failed to get stats from RC server"
    else
      echo "Remote control server is not running"
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
      pkgs.procps  # For ps command
      pkgs.gnugrep # For grep command
      pkgs.gnupg   # Required for encryption/decryption
      pkgs.coreutils # Basic utilities (mkdir, sleep, echo, date)
      pkgs.gnused # For sed used in debug script
    ];
  };
}
