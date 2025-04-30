{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.awsctx;

  # Source path to your workspace awsctx
  sourcePath = "/Users/shavakan/workspace/awsctx";

  # Repository URL - Use SSH instead of HTTPS
  repoUrl = "git@github.com:devsisters/awsctx.git";

  # Create a standalone awsctx script that doesn't depend on the repository
  awsctxScript = pkgs.writeScriptBin "awsctx" ''
    #!/usr/bin/env bash
    # Simple AWS profile context switcher

    if [ -z "$1" ]; then
      echo "Available AWS profiles:"
      aws configure list-profiles
      echo ""
      if [ -n "$AWS_PROFILE" ]; then
        echo "Current profile: $AWS_PROFILE"
      else
        echo "No AWS profile currently active"
      fi
      exit 0
    fi

    # Check if the profile exists
    if aws configure list-profiles | grep -q "^$1$"; then
      export AWS_PROFILE="$1"
      echo "Switched to AWS profile: $AWS_PROFILE"
    else
      echo "Error: AWS profile '$1' not found"
      echo "Available profiles:"
      aws configure list-profiles
      exit 1
    fi
  '';

  # Create a standalone aws profile lister
  awsLsScript = pkgs.writeScriptBin "awsls" ''
    #!/usr/bin/env bash
    # List AWS profiles

    echo "Available AWS profiles:"
    aws configure list-profiles
    
    if [ -n "$AWS_PROFILE" ]; then
      echo ""
      echo "Current profile: $AWS_PROFILE"
    fi
  '';

in
{
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
      git # Ensure git is available for cloning
      awsctxScript # Our custom awsctx script
      awsLsScript  # Our custom awsls script
    ];

    # Add awsctx to the path 
    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];

    # Create directories and clone repository via activation script
    home.activation.setupAwsctx = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Create required directories
      mkdir -p "$HOME/Library/Application Support/awsctx"
      mkdir -p "$HOME/Library/Caches/awsctx"
      mkdir -p "$HOME/workspace"
      
      # Clone repo if it doesn't exist
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
        ${pkgs.git}/bin/git clone ${repoUrl} "${sourcePath}" >/dev/null 2>&1 || \
        ${pkgs.git}/bin/git clone https://github.com/devsisters/awsctx.git "${sourcePath}" >/dev/null 2>&1
      fi
      
      # Link profiles directory
      PROFILES_SRC="${sourcePath}/profiles"
      CONFIG_DIR="$HOME/Library/Application Support/awsctx"
      PROFILES_LINK="$CONFIG_DIR/profiles"
      
      if [ -d "$PROFILES_SRC" ]; then
        # Remove old symlink or directory if it exists
        if [ -L "$PROFILES_LINK" ]; then
          rm -f "$PROFILES_LINK"
        elif [ -d "$PROFILES_LINK" ]; then
          rm -rf "$PROFILES_LINK"
        fi
        
        # Create a new symlink
        ln -sf "$PROFILES_SRC" "$PROFILES_LINK"
      fi
      
      # Create shells/zsh directory in awsctx repo if it doesn't exist
      mkdir -p "${sourcePath}/shells/zsh"
      
      # Create a simple awsctx integration file for ZSH if it doesn't exist
      if [ ! -f "${sourcePath}/shells/zsh/awsctx.zsh" ]; then
        cat > "${sourcePath}/shells/zsh/awsctx.zsh" << 'EOF'
#!/usr/bin/env zsh
# awsctx shell integration for ZSH

# Export the profile to prompt if it's set
if [ -n "$AWS_PROFILE" ]; then
  export RPROMPT="%F{blue}[$AWS_PROFILE]%f $RPROMPT"
fi

# AWS prompt update function
function aws_prompt_info() {
  if [ -n "$AWS_PROFILE" ]; then
    echo "%F{blue}[$AWS_PROFILE]%f"
  fi
}
EOF
      fi
    '';

    # Configure zsh integration
    programs.zsh = mkIf cfg.includeZshSupport {
      initExtra = ''
        # Add awsctx bin directory to PATH
        if [ -d "${sourcePath}/bin" ]; then
          export PATH="${sourcePath}/bin:$PATH"
        fi
        
        # Source awsctx zsh integration if available
        if [ -f "${sourcePath}/shells/zsh/awsctx.zsh" ]; then
          source "${sourcePath}/shells/zsh/awsctx.zsh"
        fi
        
        # Show AWS profile in prompt if set
        export RPROMPT="%F{blue}[$AWS_PROFILE]%f $RPROMPT"
      '';
    };
  };
}
