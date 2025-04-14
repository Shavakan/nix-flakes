{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone;
in
{
  options.services.rclone = {
    enable = mkEnableOption "rclone with secrets management";
    
    configFile = mkOption {
      type = types.path;
      description = "Path to the rclone configuration file";
    };
    
    targetDirectory = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.config/rclone";
      description = "Directory where the rclone configuration should be placed";
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure rclone is installed
    home.packages = with pkgs; [ 
      rclone 
      agenix 
    ];
    
    # Add an activation script to decrypt the secret
    home.activation.decryptRcloneConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Create the directory if it doesn't exist
      $DRY_RUN_CMD mkdir -p "${cfg.targetDirectory}"
      
      # Get paths
      SSH_KEY="$HOME/.ssh/id_ed25519"
      FLAKES_DIR="$HOME/nix-flakes"
      
      # Change to the nix-flakes directory
      cd "$FLAKES_DIR" || exit 1
      
      # Decrypt the file
      if [ -f "secrets/rclone.conf.age" ]; then
        $DRY_RUN_CMD ${pkgs.agenix}/bin/agenix -d "secrets/rclone.conf.age" -i "$SSH_KEY" > "${cfg.targetDirectory}/rclone.conf"
        $DRY_RUN_CMD chmod 600 "${cfg.targetDirectory}/rclone.conf"
      fi
    '';
    
  };
}
