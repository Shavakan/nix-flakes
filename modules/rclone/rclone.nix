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
    
    verbose = mkOption {
      type = types.bool;
      default = false;
      description = "Show verbose output during decryption";
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
      # Ensure the directory exists
      mkdir -p "${cfg.targetDirectory}"
      
      # Get paths
      SSH_KEY="$HOME/.ssh/id_ed25519"
      RULES_FILE="$HOME/nix-flakes/modules/agenix/ssh.nix"
      SECRET_FILE="${toString cfg.configFile}"
      TARGET_FILE="${cfg.targetDirectory}/rclone.conf"
      TEMP_FILE="${cfg.targetDirectory}/rclone.conf.tmp"
      
      # Define log function based on verbose setting
      log() {
        if [ "${toString cfg.verbose}" = "true" ]; then
          echo "$1"
        fi
      }
      
      log "Processing rclone config"
      
      # Check if the secret exists
      if [ -f "$SECRET_FILE" ]; then
        log "Secret file found"
        
        # Calculate and check hash of the secret file to detect changes
        HASH_FILE="${cfg.targetDirectory}/.rclone.conf.age.hash"
        CURRENT_HASH=$(${pkgs.coreutils}/bin/sha256sum "$SECRET_FILE" | cut -d' ' -f1)
        STORED_HASH=""
        
        if [ -f "$HASH_FILE" ]; then
          STORED_HASH=$(cat "$HASH_FILE")
        fi
        
        # If hash has changed or hash file doesn't exist, decrypt again
        if [ "$CURRENT_HASH" != "$STORED_HASH" ] || [ ! -f "$TARGET_FILE" ]; then
          log "Changes detected in secret file or target doesn't exist"
          
          # Try to decrypt with SSH key first
          if [ -f "$SSH_KEY" ]; then
            log "Using SSH key for decryption"
            # Run agenix with explicit key
            ${pkgs.agenix}/bin/agenix -d "$SECRET_FILE" -i "$SSH_KEY" > "$TEMP_FILE" 2>/dev/null
            DECRYPT_STATUS=$?
          else
            # If key not found, try with agent
            log "SSH key not found, trying with SSH agent"
            ${pkgs.agenix}/bin/agenix -d "$SECRET_FILE" > "$TEMP_FILE" 2>/dev/null
            DECRYPT_STATUS=$?
          fi
          
          # Check if decryption succeeded
          if [ $DECRYPT_STATUS -eq 0 ] && [ -s "$TEMP_FILE" ]; then
            log "Decryption successful"
            
            # Validate decrypted content (should start with [ for rclone config)
            if grep -q '^\[' "$TEMP_FILE"; then
              # Update the target file
              mv "$TEMP_FILE" "$TARGET_FILE"
              chmod 600 "$TARGET_FILE"
              
              # Create backup of working config
              cp "$TARGET_FILE" "${cfg.targetDirectory}/rclone.conf.backup" 2>/dev/null || true
              
              # Update the hash file with new hash
              echo "$CURRENT_HASH" > "$HASH_FILE"
              echo "Rclone config updated with new content"
            else
              echo "Error: Decryption succeeded but output is not a valid rclone config"
              cat "$TEMP_FILE" | head -5
              rm -f "$TEMP_FILE"
            fi
          else
            echo "Error: Failed to decrypt rclone config (status: $DECRYPT_STATUS)"
            rm -f "$TEMP_FILE"
            
            # If we have a working backup, use that
            if [ -f "${cfg.targetDirectory}/rclone.conf.backup" ]; then
              echo "Using backup rclone config"
              cp "${cfg.targetDirectory}/rclone.conf.backup" "$TARGET_FILE"
            fi
          fi
        else
          log "No changes detected in secret file, using existing config"
        fi
      else
        echo "Warning: Secret file not found at $SECRET_FILE"
      fi
    '';
  };
}
