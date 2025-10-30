{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone-mount;

  # Simplified mount script - let rclone handle initialization
  mountScript = pkgs.writeShellScriptBin "rclone-mount" ''
    #!/usr/bin/env bash
    set -e
    REMOTE="$1"
    MOUNTPOINT="$2"

    # Use shared logging from home.nix
    LOG_DIR="${config.home.homeDirectory}/nix-flakes/logs"
    mkdir -p "$LOG_DIR" 2>/dev/null || true

    log_rclone() {
      echo "$(date '+%Y-%m-%d %H:%M:%S') - $2" >> "$LOG_DIR/$1.log"
    }

    log_error() {
      local component="$1"
      local message="$2"
      echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $message" >> "$LOG_DIR/rclone-errors.log"
      log_rclone "$component" "ERROR: $message"
      echo "ERROR: $message" >&2
    }

    if [ -z "$REMOTE" ] || [ -z "$MOUNTPOINT" ]; then
      log_error "rclone-mount" "Missing arguments. Usage: rclone-mount <remote:path> <mountpoint>"
      exit 1
    fi

    MOUNTPOINT=$(eval echo "$MOUNTPOINT")

    # Quick check if already mounted and working
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $MOUNTPOINT " && ls -la "$MOUNTPOINT" >/dev/null 2>&1; then
      log_rclone "rclone-mount" "$MOUNTPOINT already mounted and accessible"
      exit 0
    fi

    # Ensure mount point exists
    ${pkgs.coreutils}/bin/mkdir -p "$MOUNTPOINT" || {
      log_error "rclone-mount" "Failed to create mount point: $MOUNTPOINT"
      exit 1
    }

    # Verify config exists
    CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
    if [ ! -f "$CONFIG_FILE" ]; then
      log_error "rclone-mount" "Rclone config not found at $CONFIG_FILE"
      exit 1
    fi

    # Check remote exists
    REMOTE_NAME=$(echo $REMOTE | cut -d: -f1)
    if ! ${pkgs.rclone}/bin/rclone listremotes --config="$CONFIG_FILE" | grep -q "^$REMOTE_NAME:"; then
      log_error "rclone-mount" "Remote '$REMOTE_NAME' not found"
      exit 1
    fi

    # Clean up any stale mounts
    ${pkgs.procps}/bin/pkill -f "rclone.*mount.*$MOUNTPOINT" 2>/dev/null || true
    sleep 1
    if command -v diskutil >/dev/null 2>&1; then
      diskutil unmount force "$MOUNTPOINT" 2>/dev/null || true
    fi

    # Mount with daemon mode
    log_rclone "rclone-mount" "Mounting $REMOTE to $MOUNTPOINT"
    ${pkgs.rclone}/bin/rclone mount "$REMOTE" "$MOUNTPOINT" \
      --config="$CONFIG_FILE" \
      --vfs-cache-mode writes \
      --vfs-cache-max-age 24h \
      --buffer-size 64M \
      --allow-non-empty \
      --cache-dir="$HOME/.cache/rclone" \
      --log-level=INFO \
      --log-file="$LOG_DIR/rclone-mount.log" \
      --daemon \
      --rc \
      --rc-addr=127.0.0.1:0 \
      --rc-no-auth \
      --volname="rclone-$REMOTE_NAME"

    # Simple verification (rclone daemon will continue initializing in background)
    sleep 2
    if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $MOUNTPOINT "; then
      log_rclone "rclone-mount" "Successfully mounted $REMOTE"
      exit 0
    else
      log_error "rclone-mount" "Mount initiation may have failed, check logs"
      exit 1
    fi
  '';

  unmountScript = pkgs.writeShellScriptBin "rclone-unmount" ''
    #!/usr/bin/env bash
    MOUNTPOINT="$1"

    if [ -z "$MOUNTPOINT" ]; then
      echo "Usage: rclone-unmount <mountpoint>"
      exit 1
    fi

    MOUNTPOINT=$(eval echo "$MOUNTPOINT")

    if ! /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $MOUNTPOINT "; then
      echo "Not mounted: $MOUNTPOINT"
      exit 0
    fi

    echo "Unmounting: $MOUNTPOINT"
    ${pkgs.procps}/bin/pkill -f "rclone.*mount.*$MOUNTPOINT" 2>/dev/null || true
    sleep 1

    if command -v diskutil >/dev/null 2>&1; then
      diskutil unmount force "$MOUNTPOINT" 2>/dev/null || true
    fi

    echo "Unmounted: $MOUNTPOINT"
  '';

  statusScript = pkgs.writeShellScriptBin "rclone-status" ''
    echo "=== Rclone Mount Status ==="
    MOUNTS=$(/sbin/mount | ${pkgs.gnugrep}/bin/grep -E '(rclone|osxfuse|macfuse)')

    if [ -z "$MOUNTS" ]; then
      echo "No rclone mounts found"
    else
      echo "Active mounts:"
      echo "$MOUNTS"
    fi
  '';

  listRemotesScript = pkgs.writeShellScriptBin "rclone-list-remotes" ''
    CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
    if [ -f "$CONFIG_FILE" ]; then
      echo "Available remotes:"
      ${pkgs.rclone}/bin/rclone listremotes --config="$CONFIG_FILE"
    else
      echo "Rclone config not found at $CONFIG_FILE"
      exit 1
    fi
  '';

  syncScript = pkgs.writeShellScriptBin "rclone-sync" ''
    echo "Syncing rclone VFS caches..."

    RC_PORTS=$(${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep rclone | ${pkgs.gnugrep}/bin/grep -o "rc-addr=127.0.0.1:[0-9]*" | ${pkgs.gnused}/bin/sed 's/rc-addr=127.0.0.1://' || true)

    if [ -z "$RC_PORTS" ]; then
      echo "No active rclone mounts with remote control found"
      exit 0
    fi

    SYNC_COUNT=0
    for PORT in $RC_PORTS; do
      if ${pkgs.netcat}/bin/nc -z 127.0.0.1 $PORT 2>/dev/null; then
        ${pkgs.rclone}/bin/rclone rc --rc-addr=127.0.0.1:$PORT vfs/refresh >/dev/null 2>&1 && SYNC_COUNT=$((SYNC_COUNT + 1))
      fi
    done

    echo "Synced $SYNC_COUNT mount(s)"
  '';

in
{
  options.services.rclone-mount = {
    enable = mkEnableOption "rclone mount service";

    mounts = mkOption {
      type = types.listOf (types.submodule {
        options = {
          remote = mkOption {
            type = types.str;
            description = "Remote path to mount (e.g., gdrive:backup)";
          };

          mountPoint = mkOption {
            type = types.str;
            description = "Local directory where the remote will be mounted";
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

    linkedConfigurations = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the configuration";
          };

          sourcePath = mkOption {
            type = types.str;
            description = "Path within the mount";
          };

          targetPath = mkOption {
            type = types.str;
            description = "Target symlink path";
          };

          permissions = mkOption {
            type = types.str;
            default = "600";
            description = "File permissions";
          };

          createTargetDir = mkOption {
            type = types.bool;
            default = true;
            description = "Create target directory if needed";
          };

          backupExisting = mkOption {
            type = types.bool;
            default = true;
            description = "Backup existing files";
          };
        };
      });
      default = [ ];
      description = "Configurations to link from mount";
    };

    environmentVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables for linked configurations";
    };
  };

  config = mkIf cfg.enable {
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
      pkgs.macfuse-stubs
    ];

    # Simplified mount activation
    home.activation.mountRcloneRemotes = lib.hm.dag.entryAfter [ "setupLogging" "decryptRcloneConfig" ] ''
      log_nix "rclone-mount" "Starting mount activation"

      # Check for macFUSE
      if [ ! -d "/Library/Frameworks/macFUSE.framework" ]; then
        log_nix "rclone-mount" "ERROR: macFUSE not found - install from https://osxfuse.github.io/"
        exit 0
      fi

      CONFIG_FILE="$HOME/.config/rclone/rclone.conf"
      if [ ! -f "$CONFIG_FILE" ]; then
        log_nix "rclone-mount" "ERROR: Config file not found"
        exit 0
      fi

      # Mount each remote
      ${concatMapStringsSep "\n" (mount: ''
        EXPANDED_MOUNT=$(eval echo "${mount.mountPoint}")

        if /sbin/mount | ${pkgs.gnugrep}/bin/grep -q " $EXPANDED_MOUNT " && ls -la "$EXPANDED_MOUNT" >/dev/null 2>&1; then
          log_nix "rclone-mount" "${mount.remote} already mounted"
        else
          ${mountScript}/bin/rclone-mount "${mount.remote}" "${mount.mountPoint}" || log_nix "rclone-mount" "ERROR: Failed to mount ${mount.remote}"
        fi
      '') cfg.mounts}

      log_nix "rclone-mount" "Mount activation complete"
    '';

    # Simplified link activation
    home.activation.linkMountConfigurations = lib.hm.dag.entryAfter [ "setupLogging" "mountRcloneRemotes" ] ''
      link_configuration() {
        local source_file="$1"
        local target_file="$2"
        local permissions="$3"
        local backup="$4"

        target_file=$(eval echo "$target_file")
        local target_dir=$(dirname "$target_file")

        mkdir -p "$target_dir" 2>/dev/null || true

        if [ -e "$source_file" ]; then
          # Check if already correctly linked
          if [ -L "$target_file" ]; then
            local current_target=$(readlink "$target_file")
            if [ "$current_target" = "$source_file" ]; then
              return 0
            fi
            # Wrong target - remove and recreate
            rm "$target_file" 2>/dev/null || true
          elif [ -e "$target_file" ] && [ "$backup" = "true" ]; then
            mv "$target_file" "$target_file.backup" 2>/dev/null || true
          fi

          ln -sf "$source_file" "$target_file"
          chmod $permissions "$target_file" 2>/dev/null || true
        fi
      }

      ${if (length cfg.mounts) > 0 then
        let firstMount = elemAt cfg.mounts 0; in
        ''
        MOUNT_POINT=$(eval echo "${firstMount.mountPoint}")

        if [ -d "$MOUNT_POINT" ]; then
          ${concatMapStringsSep "\n" (linkConfig: ''
            link_configuration "$MOUNT_POINT/${linkConfig.sourcePath}" \
                              "${linkConfig.targetPath}" \
                              "${linkConfig.permissions}" \
                              "${toString linkConfig.backupExisting}"
          '') cfg.linkedConfigurations}
        fi
        ''
      else "true"}
    '';

    home.sessionVariables = cfg.environmentVariables;
  };
}
