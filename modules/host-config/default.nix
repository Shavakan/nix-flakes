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
in {
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
    home.activation.detectMachineType = lib.hm.dag.entryBefore ["writeBoundary"] ''
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
      elif [[ "$CURRENT_HOSTNAME" == macstudio* ]]; then
        MACHINE_TYPE="macstudio"
      fi
    '';
  };
}
