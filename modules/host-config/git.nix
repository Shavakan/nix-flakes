{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.host-config;
  
  # Machine configs - must match those in default.nix
  machineConfigs = {
    "macbook" = {
      gitSigningKey = "1193AD54623C8450";
      enableGitSigning = true;
    };
    
    "macstudio" = {
      gitSigningKey = "01FA3FC79AD70686";
      enableGitSigning = true;
    };
  };
in {
  # Configure git with machine-specific signing key
  config = {
    # Create an early activation script for git config 
    home.activation.setupGitConfig = lib.hm.dag.entryBefore ["writeBoundary"] ''
      # Get current hostname using full path to hostname command
      if [ -x /bin/hostname ]; then
        HOSTNAME_CMD="/bin/hostname"
      elif [ -x /usr/bin/hostname ]; then
        HOSTNAME_CMD="/usr/bin/hostname"
      else
        CURRENT_HOSTNAME="unknown"
      fi
      
      if [ -n "$HOSTNAME_CMD" ]; then
        CURRENT_HOSTNAME=$($HOSTNAME_CMD | tr -d '\n')
      fi
      
      # Determine machine type based on hostname
      MACHINE_TYPE="unknown"
      if [[ "$CURRENT_HOSTNAME" == MacBook* ]]; then
        MACHINE_TYPE="macbook"
      elif [[ "$CURRENT_HOSTNAME" == macstudio* ]]; then
        MACHINE_TYPE="macstudio"
      fi
      
      # Get the appropriate git signing key based on machine type
      GIT_SIGNING_KEY=""
      ENABLE_GIT_SIGNING="false"
      
      if [ "$MACHINE_TYPE" == "macbook" ]; then
        GIT_SIGNING_KEY="${machineConfigs.macbook.gitSigningKey}"
        ENABLE_GIT_SIGNING="${toString machineConfigs.macbook.enableGitSigning}"
      elif [ "$MACHINE_TYPE" == "macstudio" ]; then
        GIT_SIGNING_KEY="${machineConfigs.macstudio.gitSigningKey}"
        ENABLE_GIT_SIGNING="${toString machineConfigs.macstudio.enableGitSigning}"
      fi
      
      $DRY_RUN_CMD mkdir -p "$HOME/.config/git" >/dev/null 2>&1
      
      # Create a temporary git config with essential settings
      TMP_GIT_CONFIG=$(mktemp)
      
      # Start with base configuration
      cat > "$TMP_GIT_CONFIG" << EOF
[user]
    name = ChangWon Lee
    email = cs.changwon.lee@gmail.com
[core]
    editor = nvim
[url "git@github.com:"]
    insteadOf = https://github.com/
[url "git@gitlab.com:"]
    insteadOf = https://gitlab.com/
[url "https://"]
    insteadOf = git://
[push]
    autoSetupRemote = true
    default = current
EOF
      
      # Add signing configuration only if enabled for this machine type
      if [ "$ENABLE_GIT_SIGNING" = "true" ] && [ -n "$GIT_SIGNING_KEY" ]; then
        cat >> "$TMP_GIT_CONFIG" << EOF
[user]
    signingkey = $GIT_SIGNING_KEY
[gpg]
    program = gpg
[commit]
    gpgsign = true
EOF
      fi
      
      # Only copy if different or if no git config exists
      if [ ! -f "$HOME/.gitconfig" ] || ! cmp -s "$TMP_GIT_CONFIG" "$HOME/.gitconfig"; then
        $DRY_RUN_CMD cp "$TMP_GIT_CONFIG" "$HOME/.gitconfig"
      fi
      
      rm -f "$TMP_GIT_CONFIG"
    '';
  };
}
