{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.cd-rclone;
in
{
  options.programs.cd-rclone = {
    enable = mkEnableOption "cd-rclone command for quick navigation to rclone mounts";

    mountBase = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/mnt/rclone";
      description = "Base directory where rclone mounts are located";
    };

    extraDirs = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = literalExpression ''
        {
          kube = "kubeconfigs";
          docs = "documents";
        }
      '';
      description = "Extra directory shortcuts for quick navigation";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      (writeShellScriptBin "cd-rclone" ''
        #!/usr/bin/env bash
        
        # Base directory for rclone mounts
        MOUNT_BASE="${cfg.mountBase}"
        
        # Define shortcut directories
        declare -A DIRS=(
          ${concatStringsSep "\n  " (mapAttrsToList (name: path: "[${name}]=\"${path}\"") cfg.extraDirs)}
        )
        
        # Function to display help message
        show_help() {
          echo "Usage: cd-rclone [OPTION]"
          echo
          echo "Change directory to rclone mount locations."
          echo
          echo "Options:"
          echo "  -h, --help     Display this help message"
          echo "  -l, --list     List available shortcuts"
          echo "  <shortcut>     Navigate to a specific shortcut directory"
          echo "  (no args)      Show the base mount directory (${cfg.mountBase})"
          echo
          echo "Available shortcuts:"
          for key in "''${!DIRS[@]}"; do
            echo "  $key -> ''${DIRS[$key]}"
          done
        }
        
        # Check if the mount directory exists
        if [[ ! -d "$MOUNT_BASE" ]]; then
          echo "Error: Mount directory $MOUNT_BASE does not exist!"
          echo "Make sure rclone is properly mounted."
          exit 1
        fi
        
        # Parse arguments
        if [[ $# -eq 0 ]]; then
          # No arguments - print base directory
          echo "$MOUNT_BASE"
        elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
          # Help option
          show_help
        elif [[ "$1" == "-l" || "$1" == "--list" ]]; then
          # List option
          echo "Available rclone mount shortcuts:"
          for key in "''${!DIRS[@]}"; do
            echo "  $key -> $MOUNT_BASE/''${DIRS[$key]}"
          done
        elif [[ -n "''${DIRS[$1]}" ]]; then
          # Print shortcut path
          TARGET="$MOUNT_BASE/''${DIRS[$1]}"
          if [[ ! -d "$TARGET" ]]; then
            echo "Warning: Directory $TARGET does not exist!"
            echo "Creating directory..."
            mkdir -p "$TARGET"
          fi
          echo "$TARGET"
        else
          # Try direct subdirectory
          TARGET="$MOUNT_BASE/$1"
          if [[ -d "$TARGET" ]]; then
            echo "$TARGET"
          else
            echo "Error: Unknown shortcut or directory: $1"
            echo "Run 'cd-rclone --list' to see available shortcuts."
            exit 1
          fi
        fi
      '')
    ];

    # Add shell function for zsh only
    programs.zsh.initExtra = mkIf config.programs.zsh.enable ''
      # cd-rclone function for zsh
      cdr() {
        if [ "$#" -eq 0 ]; then
          cd "$(cd-rclone)"
        elif [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "-l" ] || [ "$1" = "--list" ]; then
          cd-rclone "$@"
        else
          cd "$(cd-rclone "$@")"
        fi
      }
    '';
  };
}
