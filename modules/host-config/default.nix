{ config, lib, pkgs, ... }:

with lib;

let
  # Machine configs for different machine types
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
in
{
  # Export config values for other modules
  options.host-config = {
    gitSigningKey = mkOption {
      type = types.str;
      default = "";
      description = "GPG key ID to use for git commit signing on this host";
    };

    enableGitSigning = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable git commit signing on this host";
    };
  };

  config = {
    # Default values for host-config options
    host-config.gitSigningKey = mkDefault "";
    host-config.enableGitSigning = mkDefault false;

    # Add activation script to detect hostname and machine type at runtime
    home.activation.detectMachineType = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      # Detect hostname and machine type silently
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
      
      MACHINE_TYPE="unknown"
      if [[ "$CURRENT_HOSTNAME" == MacBook* ]]; then
        MACHINE_TYPE="macbook"
        
        # Set host-config values for MacBook
        echo "${machineConfigs.macbook.gitSigningKey}" > "$HOME/.nix-host-git-key"
        echo "${toString machineConfigs.macbook.enableGitSigning}" > "$HOME/.nix-host-git-sign"
        
      elif [[ "$CURRENT_HOSTNAME" == macstudio* ]]; then
        MACHINE_TYPE="macstudio"
        
        # Set host-config values for Mac Studio
        echo "${machineConfigs.macstudio.gitSigningKey}" > "$HOME/.nix-host-git-key"
        echo "${toString machineConfigs.macstudio.enableGitSigning}" > "$HOME/.nix-host-git-sign"
      fi
    '';

    # Set up another activation script that will run after the git config is created
    home.activation.setupGitSigningKey = lib.hm.dag.entryAfter [ "detectMachineType" ] ''
      # Check if the files exist
      if [ -f "$HOME/.nix-host-git-key" ] && [ -f "$HOME/.nix-host-git-sign" ]; then
        GIT_SIGNING_KEY=$(cat "$HOME/.nix-host-git-key")
        ENABLE_GIT_SIGNING=$(cat "$HOME/.nix-host-git-sign")
        
        # Update the git config with the signing key
        if [ -n "$GIT_SIGNING_KEY" ] && [ "$ENABLE_GIT_SIGNING" = "true" ]; then
          $DRY_RUN_CMD ${pkgs.git}/bin/git config --global user.signingkey "$GIT_SIGNING_KEY"
          $DRY_RUN_CMD ${pkgs.git}/bin/git config --global commit.gpgsign "true"
          $DRY_RUN_CMD ${pkgs.git}/bin/git config --global gpg.program "${pkgs.gnupg}/bin/gpg"
        else
          # Disable signing if not enabled
          $DRY_RUN_CMD ${pkgs.git}/bin/git config --global --unset user.signingkey || true
          $DRY_RUN_CMD ${pkgs.git}/bin/git config --global commit.gpgsign "false"
        fi
      fi
    '';
  };
}
