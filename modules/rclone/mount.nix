{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone-mount;

  # Create a simple script for each mount operation
  mountScript = pkgs.writeShellScriptBin "rclone-mount" ''
    #!/usr/bin/env bash
    REMOTE="$1"
    MOUNTPOINT="$2"
    
    if [ -z "$REMOTE" ] || [ -z "$MOUNTPOINT" ]; then
      echo "Usage: rclone-mount <remote:path> <mountpoint>"
      exit 1
    fi
    
    # Check if already mounted
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q "$MOUNTPOINT"; then
      exit 0  # Already mounted, silently exit
    fi
    
    # Ensure the mount point exists
    ${pkgs.coreutils}/bin/mkdir -p "$MOUNTPOINT" >/dev/null 2>&1
    
    # Verify config file exists
    if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
      echo "Error: rclone config file not found"
      exit 1
    fi
    
    # Check if remote exists in config
    if ! ${pkgs.rclone}/bin/rclone listremotes 2>/dev/null | grep -q "^$(echo $REMOTE | cut -d: -f1):"; then
      echo "Error: Remote '$(echo $REMOTE | cut -d: -f1)' not found in rclone config"
      exit 1
    fi
    
    # Unmount first if needed (silently)
    if command -v diskutil >/dev/null 2>&1; then
      diskutil unmount force "$MOUNTPOINT" >/dev/null 2>&1 || true
    else
      umount -f "$MOUNTPOINT" >/dev/null 2>&1 || true
    fi
    
    # Mount the remote filesystem with improved options (silently)
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
      --daemon \
      --rc \
      --rc-addr=127.0.0.1:0 >/dev/null 2>&1
      
    # Wait a moment for mount to initialize
    ${pkgs.coreutils}/bin/sleep 1 >/dev/null 2>&1
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
      pkgs.rclone
      pkgs.netcat
      pkgs.procps
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.gnused
    ];

    # Create an activation script to mount remotes silently
    home.activation.mountRcloneRemotes = lib.hm.dag.entryAfter [ "decryptRcloneConfig" ] ''
      # Check if config file exists first
      CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
      
      # Only run the mount script if config file exists
      if [ -f "$CONFIG_FILE" ]; then
        # Mount each configured remote silently
        ${concatMapStringsSep "\n" (mount: ''
          ${mountScript}/bin/rclone-mount "${mount.remote}" "${mount.mountPoint}" >/dev/null 2>&1
        '') cfg.mounts}
      fi
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
