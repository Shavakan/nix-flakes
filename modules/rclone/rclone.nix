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
      SECRET_FILE="$HOME/nix-flakes/modules/agenix/rclone.conf.age"
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
          
          # Try with SSH key if available
          if [ -f "$SSH_KEY" ]; then
            log "Using SSH key"
            rm -f "$TEMP_FILE"
            ${pkgs.coreutils}/bin/timeout 10s ${pkgs.agenix}/bin/agenix -d "$SECRET_FILE" -i "$SSH_KEY" -r "$RULES_FILE" > "$TEMP_FILE" 2>/tmp/agenix-error.log || true
          else
            log "Using SSH agent"
            rm -f "$TEMP_FILE"
            ${pkgs.coreutils}/bin/timeout 10s ${pkgs.agenix}/bin/agenix -d "$SECRET_FILE" -r "$RULES_FILE" > "$TEMP_FILE" 2>/tmp/agenix-error.log || true
          fi
          
          # Check if the temp file was created and has content
          if [ -f "$TEMP_FILE" ] && [ -s "$TEMP_FILE" ]; then
            log "Decryption successful"
            
            # Update the target file
            mv "$TEMP_FILE" "$TARGET_FILE"
            chmod 600 "$TARGET_FILE"
            
            # Create backup of working config
            cp "$TARGET_FILE" "${cfg.targetDirectory}/rclone.conf.backup" 2>/dev/null || true
            
            # Update the hash file with new hash
            echo "$CURRENT_HASH" > "$HASH_FILE"
            echo "Rclone config updated with new content"
          else
            # If decryption failed but we have a valid config, just keep using it
            if [ ! -f "$TARGET_FILE" ] || [ ! -s "$TARGET_FILE" ]; then
              if [ "${toString cfg.verbose}" = "true" ] && [ -f "/tmp/agenix-error.log" ]; then
                echo "Decryption failed with errors:"
                cat "/tmp/agenix-error.log"
              fi
              echo "No valid rclone config available"
            else
              log "Decryption failed, using existing config"
            fi
          fi
        else
          log "No changes detected in secret file, using existing config"
        fi
      fi
    '';
  };
}

