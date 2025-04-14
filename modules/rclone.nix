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
    
    # Add an activation script to decrypt the secret (only when needed)
    home.activation.decryptRcloneConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Create the directory if it doesn't exist
      $DRY_RUN_CMD mkdir -p "${cfg.targetDirectory}"
      
      # Get paths
      SSH_KEY="$HOME/.ssh/id_ed25519"
      FLAKES_DIR="$HOME/nix-flakes"
      SECRET_FILE="secrets/rclone.conf.age"
      TARGET_FILE="${cfg.targetDirectory}/rclone.conf"
      SECRET_HASH_FILE="${cfg.targetDirectory}/.rclone.conf.age.hash"
      
      # Change to the nix-flakes directory
      cd "$FLAKES_DIR" || exit 1
      
      # Check if the secret exists
      if [ -f "$SECRET_FILE" ]; then
        # Check if we need to decrypt by comparing hashes
        CURRENT_HASH=$(${pkgs.coreutils}/bin/sha256sum "$SECRET_FILE" | cut -d' ' -f1)
        NEED_DECRYPT=1
        
        # If hash file exists and matches, we can skip decryption
        if [ -f "$SECRET_HASH_FILE" ] && [ -f "$TARGET_FILE" ]; then
          STORED_HASH=$(cat "$SECRET_HASH_FILE")
          if [ "$CURRENT_HASH" = "$STORED_HASH" ]; then
            echo "Rclone config unchanged - using existing decrypted file"
            NEED_DECRYPT=0
          fi
        fi
        
        # Only decrypt if needed
        if [ $NEED_DECRYPT -eq 1 ]; then
          echo "Decrypting rclone config (hash changed or first run)"
          # Try to decrypt using SSH key directly
          $DRY_RUN_CMD ${pkgs.agenix}/bin/agenix -d "$SECRET_FILE" -i "$SSH_KEY" > "$TARGET_FILE"
          
          # Set proper permissions
          if [ -f "$TARGET_FILE" ]; then
            $DRY_RUN_CMD chmod 600 "$TARGET_FILE"
            # Store the hash for future comparisons
            echo "$CURRENT_HASH" > "$SECRET_HASH_FILE"
          fi
        fi
      fi
    '';
    
  };
}
