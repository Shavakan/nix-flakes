{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mas;
in {
  options.services.mas = {
    enable = mkEnableOption "Mac App Store CLI and application management";

    apps = mkOption {
      type = types.attrsOf types.int;
      default = {};
      example = {
        "AppName1" = 123456789;
        "AppName2" = 987654321;
      };
      description = "Applications to install from the Mac App Store, with their IDs";
    };

    appleId = mkOption {
      type = types.str;
      default = "";
      example = "user@example.com";
      description = "Apple ID email to sign in to the Mac App Store";
    };
  };

  config = mkIf cfg.enable {
    # Add mas to packages
    home.packages = [ pkgs.mas ];

    # Create activation script for Mac App Store apps with quiet output
    home.activation.manageMacAppStore = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Set up logging in the nix-flakes/logs directory
      MAS_LOG_DIR="$HOME/nix-flakes/logs"
      MAS_LOG="$MAS_LOG_DIR/mas.log"
      mkdir -p "$MAS_LOG_DIR" > /dev/null 2>&1
      
      # Log function
      log_mas() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$MAS_LOG"
      }
      
      log_mas "Starting Mac App Store app management"
      
      # Try to sign in if not already signed in and Apple ID is provided
      if [ -n "${cfg.appleId}" ] && ! ${pkgs.mas}/bin/mas account >/dev/null 2>&1; then
        log_mas "Signing in to Mac App Store as ${cfg.appleId}"
        ${pkgs.mas}/bin/mas signin "${cfg.appleId}" >/dev/null 2>&1 || log_mas "Sign-in failed, may need manual sign-in via App Store UI"
      fi
      
      # Verify sign-in status
      if ${pkgs.mas}/bin/mas account >/dev/null 2>&1; then
        ACCOUNT=$(${pkgs.mas}/bin/mas account 2>/dev/null)
        log_mas "Mac App Store: Signed in as $ACCOUNT"
      else
        log_mas "Not signed in to Mac App Store. Some operations may fail."
      fi
      
      # Install all configured apps silently
      ${concatStringsSep "\n" (mapAttrsToList (name: id: ''
        log_mas "Processing ${name} (${toString id})"
        APP_PATH="/Applications/${name}.app"
        
        # Check if already installed
        if [ -d "$APP_PATH" ]; then
          log_mas "${name} is already installed"
        else
          log_mas "Installing ${name} from Mac App Store"
          $DRY_RUN_CMD ${pkgs.mas}/bin/mas install "${toString id}" >/dev/null 2>&1
          
          # Check installation result
          if [ -d "$APP_PATH" ]; then
            log_mas "${name} installed successfully"
          else
            log_mas "Could not verify ${name} installation, may require manual installation"
          fi
        fi
      '') cfg.apps)}
    '';
  };
}