{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.awsctx;
  
  # Source path to your workspace awsctx
  sourcePath = "/Users/shavakan/workspace/awsctx";
  
  # Helper function to create directories
  createDirs = pkgs.writeShellScript "create-awsctx-dirs" ''
    mkdir -p "$HOME/Library/Application Support/awsctx"
    mkdir -p "$HOME/Library/Caches/awsctx"
  '';
  
  # Copy the profiles to the config directory
  setupProfiles = pkgs.writeShellScript "setup-awsctx-profiles" ''
    ${createDirs}
    
    # Source path to profiles
    PROFILES_SRC="${sourcePath}/profiles"
    
    # Destination for configs
    CONFIG_DIR="$HOME/Library/Application Support/awsctx"
    
    # Copy all config files (except shell scripts)
    for config_file in "$PROFILES_SRC"/*.config; do
      if [ -f "$config_file" ]; then
        base_name=$(basename "$config_file")
        cp -f "$config_file" "$CONFIG_DIR/$base_name"
      fi
    done
    
    # Create symbolic links for awsctx binaries and scripts
    mkdir -p "$HOME/.local/bin"
    ln -sf "${sourcePath}/bin/aws-login-all" "$HOME/.local/bin/aws-login-all"
    chmod +x "$HOME/.local/bin/aws-login-all"
    
    echo "Configured awsctx profiles in $CONFIG_DIR"
  '';
  
in {
  options.services.awsctx = {
    enable = mkEnableOption "awsctx AWS profile context switcher";
    
    includeFishSupport = mkOption {
      type = types.bool;
      default = true;
      description = "Include Fish shell support";
    };
    
    includeBashSupport = mkOption {
      type = types.bool;
      default = true;
      description = "Include Bash shell support";
    };
    
    includeTidePrompt = mkOption {
      type = types.bool;
      default = false;
      description = "Include Tide prompt integration for Fish shell";
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure required packages are installed
    home.packages = with pkgs; [ 
      saml2aws
      coreutils
      findutils
    ];
    
    # Add awsctx to the path 
    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
    
    # Create directories and setup profiles
    home.activation.setupAwsctx = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${setupProfiles}
    '';
    
    # Configure shell integrations
    programs.bash = mkIf cfg.includeBashSupport {
      initExtra = ''
        # Source awsctx for bash
        source "${sourcePath}/shells/bash/awsctx.sh"
      '';
    };
    
    programs.fish = mkIf cfg.includeFishSupport {
      interactiveShellInit = ''
        # Configure awsctx for fish
        if not functions -q awsctx
          source "${sourcePath}/shells/fish/functions/awsctx.fish"
        end
      '';

      # Add completions for fish shell
      shellInit = ''
        # Add awsctx completions
        if test -d "${sourcePath}/shells/fish/completions"
          set -p fish_complete_path "${sourcePath}/shells/fish/completions"
        end
      '';
    };
    
    # Setup Tide prompt integration if enabled
    home.file = mkIf (cfg.includeFishSupport && cfg.includeTidePrompt) {
      ".config/fish/conf.d/tide_awsctx.fish".source = "${sourcePath}/prompts/tide/conf.d/tide_awsctx.fish";
      ".config/fish/functions/_tide_item_awsctx.fish".source = "${sourcePath}/prompts/tide/functions/_tide_item_awsctx.fish";
    };
  };
}
