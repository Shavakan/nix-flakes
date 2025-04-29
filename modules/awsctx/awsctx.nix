{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.awsctx;
  
  # Source path to your workspace awsctx
  sourcePath = "/Users/shavakan/workspace/awsctx";
  
  # Repository URL - Use SSH instead of HTTPS
  repoUrl = "git@github.com:devsisters/awsctx.git";
  
  # Helper function to create directories
  createDirs = pkgs.writeShellScript "create-awsctx-dirs" ''
    mkdir -p "$HOME/Library/Application Support/awsctx"
    mkdir -p "$HOME/Library/Caches/awsctx"
    mkdir -p "$HOME/workspace"
  '';
  
  # Clone the repository if it doesn't exist
  cloneRepo = pkgs.writeShellScript "clone-awsctx-repo" ''
    ${createDirs}
    
    # Check if the repository already exists
    if [ ! -d "${sourcePath}" ]; then
      echo "Cloning awsctx repository to ${sourcePath}..."
      mkdir -p "$(dirname "${sourcePath}")"
      
      # Check if SSH key exists and has proper permissions
      SSH_KEY="$HOME/.ssh/id_ed25519"
      if [ -f "$SSH_KEY" ]; then
        # Ensure proper permissions
        chmod 600 "$SSH_KEY" 2>/dev/null || true
      fi
      
      # Clone with appropriate settings
      GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
      ${pkgs.git}/bin/git clone ${repoUrl} "${sourcePath}"
      
      if [ $? -eq 0 ]; then
        echo "Repository cloned successfully!"
      else
        echo "Error cloning repository. Trying alternative URL..."
        # Fallback to HTTPS if SSH fails
        ${pkgs.git}/bin/git clone https://github.com/devsisters/awsctx.git "${sourcePath}"
      fi
    else
      echo "awsctx repository already exists at ${sourcePath}"
      
      # Make sure the repository uses the right remote URL
      CURRENT_URL=$(cd "${sourcePath}" && ${pkgs.git}/bin/git remote get-url origin 2>/dev/null)
      if [ "$CURRENT_URL" = "https://github.com/devsisters/awsctx.git" ]; then
        echo "Updating remote URL to use SSH..."
        (cd "${sourcePath}" && ${pkgs.git}/bin/git remote set-url origin ${repoUrl})
      fi
    fi
  '';
  
  # Copy the profiles to the config directory
  setupProfiles = pkgs.writeShellScript "setup-awsctx-profiles" ''
    # First ensure the repository is cloned
    ${cloneRepo}
    
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
    
    echo "Configured awsctx profiles in $CONFIG_DIR"
  '';
  
  # Create activation script for the AWS login all command
  aws_login_all = pkgs.writeShellScriptBin "aws-login-all" ''
    #!/bin/bash
    source "${sourcePath}/bin/aws-login-all"
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
      aws_login_all
      saml2aws
      coreutils
      findutils
      git  # Ensure git is available for cloning
    ];
    
    # Add awsctx to the path 
    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
    
    # Create directories, clone repository, and setup profiles
    # Run after git config is established
    home.activation.setupAwsctx = lib.hm.dag.entryAfter ["verifyHostname"] ''
      # Ensure git configuration is properly set
      if [ -f "$HOME/.gitconfig" ]; then
        # Explicitly set GIT_SSH_COMMAND to ensure SSH is used with proper settings
        export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
        echo "Running awsctx setup with configured git..."
        $DRY_RUN_CMD ${setupProfiles}
      else
        echo "Warning: Git configuration not found. Using default clone settings."
        $DRY_RUN_CMD ${setupProfiles}
      fi
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
    # We'll create these files during activation instead of using home.file
    # to avoid errors when the repository hasn't been cloned yet
    home.activation.setupTidePrompt = mkIf (cfg.includeFishSupport && cfg.includeTidePrompt) (
      lib.hm.dag.entryAfter ["setupAwsctx"] ''
        # Now that the repository is cloned, we can copy the tide prompt files
        if [ -f "${sourcePath}/prompts/tide/conf.d/tide_awsctx.fish" ]; then
          $DRY_RUN_CMD mkdir -p "$HOME/.config/fish/conf.d"
          $DRY_RUN_CMD cp -f "${sourcePath}/prompts/tide/conf.d/tide_awsctx.fish" "$HOME/.config/fish/conf.d/tide_awsctx.fish"
        fi
        
        if [ -f "${sourcePath}/prompts/tide/functions/_tide_item_awsctx.fish" ]; then
          $DRY_RUN_CMD mkdir -p "$HOME/.config/fish/functions"
          $DRY_RUN_CMD cp -f "${sourcePath}/prompts/tide/functions/_tide_item_awsctx.fish" "$HOME/.config/fish/functions/_tide_item_awsctx.fish"
        fi
      ''
    );
  };
}
