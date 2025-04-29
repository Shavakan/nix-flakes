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
      mkdir -p "${cfg.targetDirectory}" >/dev/null 2>&1
      
      # Get paths
      SSH_KEY="$HOME/.ssh/id_ed25519"
      RULES_FILE="$HOME/nix-flakes/modules/agenix/ssh.nix"
      SECRET_FILE="${toString cfg.configFile}"
      TARGET_FILE="${cfg.targetDirectory}/rclone.conf"
      TEMP_FILE="${cfg.targetDirectory}/rclone.conf.tmp"
      ERROR_FILE="/tmp/agenix-error.log"
      
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
          
          # Clear any previous error logs
          rm -f "$ERROR_FILE" >/dev/null 2>&1
          
          # Try to decrypt with SSH key
          if [ -f "$SSH_KEY" ]; then
            log "Using SSH key for decryption"
            rm -f "$TEMP_FILE" >/dev/null 2>&1
            
            # Run agenix with the key with minimal output
            ${pkgs.agenix}/bin/agenix -d "$SECRET_FILE" -i "$SSH_KEY" > "$TEMP_FILE" 2>"$ERROR_FILE"
            DECRYPT_STATUS=$?
          else
            # If key not found, try with agent
            log "Using SSH agent for decryption"
            rm -f "$TEMP_FILE" >/dev/null 2>&1
            
            # Try with agent
            ${pkgs.agenix}/bin/agenix -d "$SECRET_FILE" > "$TEMP_FILE" 2>"$ERROR_FILE"
            DECRYPT_STATUS=$?
          fi
          
          # Check if decryption succeeded
          if [ $DECRYPT_STATUS -eq 0 ] && [ -s "$TEMP_FILE" ]; then
            # Validate decrypted content (should start with [ for rclone config)
            if grep -q '^\[' "$TEMP_FILE"; then
              # Update the target file
              mv "$TEMP_FILE" "$TARGET_FILE" >/dev/null 2>&1
              chmod 600 "$TARGET_FILE" >/dev/null 2>&1
              
              # Create backup of working config
              cp "$TARGET_FILE" "${cfg.targetDirectory}/rclone.conf.backup" 2>/dev/null || true
              
              # Update the hash file with new hash
              echo "$CURRENT_HASH" > "$HASH_FILE"
              log "Rclone config updated successfully"
            else
              echo "Error: Decryption output is not a valid rclone config"
              rm -f "$TEMP_FILE" >/dev/null 2>&1
            fi
          else
            # Only show error in case of failure
            echo "Error: Failed to decrypt rclone config (status: $DECRYPT_STATUS)"
            
            if [ -f "$ERROR_FILE" ] && [ -s "$ERROR_FILE" ]; then
              cat "$ERROR_FILE"
            fi
            
            rm -f "$TEMP_FILE" >/dev/null 2>&1
            
            # Use backup if available
            if [ -f "${cfg.targetDirectory}/rclone.conf.backup" ]; then
              log "Using backup rclone config"
              cp "${cfg.targetDirectory}/rclone.conf.backup" "$TARGET_FILE" >/dev/null 2>&1
            fi
          fi
        else
          log "No changes detected in secret file, using existing config"
        fi
      else
        echo "Error: Secret file not found at $SECRET_FILE"
      fi
      
      # Clean up error file
      rm -f "$ERROR_FILE" >/dev/null 2>&1
    '';
  };
}
