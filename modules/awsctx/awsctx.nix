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
      mkdir -p "$(dirname "${sourcePath}")"
      
      # Check if SSH key exists and has proper permissions
      SSH_KEY="$HOME/.ssh/id_ed25519"
      if [ -f "$SSH_KEY" ]; then
        # Ensure proper permissions
        chmod 600 "$SSH_KEY" 2>/dev/null || true
      fi
      
      # Clone with appropriate settings
      GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
      ${pkgs.git}/bin/git clone ${repoUrl} "${sourcePath}" >/dev/null 2>&1
      
      if [ $? -ne 0 ]; then
        # Fallback to HTTPS if SSH fails (silently)
        ${pkgs.git}/bin/git clone https://github.com/devsisters/awsctx.git "${sourcePath}" >/dev/null 2>&1
      fi
    else
      # Make sure the repository uses the right remote URL (silently)
      CURRENT_URL=$(cd "${sourcePath}" && ${pkgs.git}/bin/git remote get-url origin 2>/dev/null)
      if [ "$CURRENT_URL" = "https://github.com/devsisters/awsctx.git" ]; then
        (cd "${sourcePath}" && ${pkgs.git}/bin/git remote set-url origin ${repoUrl}) >/dev/null 2>&1
      fi
    fi
  '';
  
  # Link the profiles directory to awsctx config instead of copying individual files
  setupProfiles = pkgs.writeShellScript "setup-awsctx-profiles" ''
    # First ensure the repository is cloned
    ${cloneRepo}
    
    # Source path to profiles directory
    PROFILES_SRC="${sourcePath}/profiles"
    
    # Destination for configs
    CONFIG_DIR="$HOME/Library/Application Support/awsctx"
    PROFILES_LINK="$CONFIG_DIR/profiles"
    
    # Create symlink for the entire profiles directory
    if [ -d "$PROFILES_SRC" ]; then
      # Remove old symlink if it exists
      if [ -L "$PROFILES_LINK" ]; then
        rm -f "$PROFILES_LINK"
      # Remove old directory if it exists
      elif [ -d "$PROFILES_LINK" ]; then
        rm -rf "$PROFILES_LINK"
      fi
      
      # Create a new symlink
      ln -sf "$PROFILES_SRC" "$PROFILES_LINK"
    fi
  '';
  
in {
  options.services.awsctx = {
    enable = mkEnableOption "awsctx AWS profile context switcher";
    
    includeZshSupport = mkOption {
      type = types.bool;
      default = true;
      description = "Include Zsh shell support";
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure required packages are installed
    home.packages = with pkgs; [ 
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
      # Run setupProfiles silently
      export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"
      $DRY_RUN_CMD ${setupProfiles} >/dev/null 2>&1
    '';
    
    # Configure zsh integration
    programs.zsh = mkIf cfg.includeZshSupport {
      initExtra = ''
        # Source awsctx for zsh
        if [ -f "${sourcePath}/shells/zsh/awsctx.zsh" ]; then
          source "${sourcePath}/shells/zsh/awsctx.zsh"
        fi
      '';
    };
  };
}
