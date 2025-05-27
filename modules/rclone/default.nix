{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.rclone;
in
{
  # Import submodules in the correct dependency order
  imports = [
    ./mount.nix
    ./launchd.nix
    ./cd-rclone
  ];

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
    home.activation.decryptRcloneConfig = lib.hm.dag.entryAfter [ "setupLogging" "writeBoundary" ] ''
      # Define log files
      ERROR_LOG="$NIX_LOG_DIR/rclone-errors.log"
      
      # Ensure the target directory exists
      mkdir -p "${cfg.targetDirectory}" >/dev/null 2>&1
      
      # Log function
      log_message() {
        log_nix "rclone-decrypt" "$1"
      }
      
      # Error log function
      log_error() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$ERROR_LOG"
        log_nix "rclone-decrypt" "ERROR: $1"
        echo "ERROR: $1" >&2
      }
      
      # Get paths - use the original flake directory structure
      SSH_KEY="$HOME/.ssh/id_ed25519"
      FLAKE_DIR="$HOME/nix-flakes"
      SECRET_FILE="modules/agenix/rclone.conf.age"  # Use relative path to match secrets.nix
      TARGET_FILE="${cfg.targetDirectory}/rclone.conf"
      TEMP_FILE="${cfg.targetDirectory}/rclone.conf.tmp"
      
      log_message "Starting rclone config decryption"
      
      # Check if the secret exists (use absolute path for checking)
      ABSOLUTE_SECRET_FILE="$FLAKE_DIR/$SECRET_FILE"
      if [ -f "$ABSOLUTE_SECRET_FILE" ]; then
        log_message "Secret file found at $ABSOLUTE_SECRET_FILE"
        
        # Calculate and check hash of the secret file to detect changes
        HASH_FILE="${cfg.targetDirectory}/.rclone.conf.age.hash"
        CURRENT_HASH=$(${pkgs.coreutils}/bin/sha256sum "$ABSOLUTE_SECRET_FILE" | cut -d' ' -f1)
        STORED_HASH=""
        
        if [ -f "$HASH_FILE" ]; then
          STORED_HASH=$(cat "$HASH_FILE")
        fi
        
        # If hash has changed or hash file doesn't exist, decrypt again
        if [ "$CURRENT_HASH" != "$STORED_HASH" ] || [ ! -f "$TARGET_FILE" ]; then
          log_message "Changes detected in secret file or target doesn't exist, attempting decryption"
          
          # Clear any previous temp files
          rm -f "$TEMP_FILE" >/dev/null 2>&1
          
          # Change to the flake directory for proper context
          ORIGINAL_DIR=$(pwd)
          cd "$FLAKE_DIR" || {
            log_error "Cannot change to flake directory $FLAKE_DIR"
            exit 1
          }
          
          if [ -f "$SSH_KEY" ]; then
            log_message "Using SSH key for decryption: $SSH_KEY"
            
            "${pkgs.agenix}/bin/agenix" -d "$SECRET_FILE" -i "$SSH_KEY" > "$TEMP_FILE" 2>>"$ERROR_LOG"
            DECRYPT_STATUS=$?
          else
            log_message "SSH key not found, trying without identity"

            "${pkgs.agenix}/bin/agenix" -d "$SECRET_FILE" > "$TEMP_FILE" 2>>"$ERROR_LOG"
            DECRYPT_STATUS=$?
          fi
          
          # Return to original directory
          cd "$ORIGINAL_DIR"
          
          # Check if decryption succeeded
          if [ $DECRYPT_STATUS -eq 0 ] && [ -s "$TEMP_FILE" ]; then
            # Validate decrypted content (should start with [ for rclone config or contain config data)
            if grep -q '^\[' "$TEMP_FILE" || grep -q 'type.*=' "$TEMP_FILE"; then
              # Update the target file
              mv "$TEMP_FILE" "$TARGET_FILE" >/dev/null 2>&1
              chmod 600 "$TARGET_FILE" >/dev/null 2>&1
              
              # Create backup of working config
              cp "$TARGET_FILE" "${cfg.targetDirectory}/rclone.conf.backup" 2>/dev/null || true
              
              # Update the hash file with new hash
              echo "$CURRENT_HASH" > "$HASH_FILE"
              log_message "Rclone config decryption successful"
            else
              log_error "Decrypted content does not appear to be a valid rclone config"
              log_error "Content preview: $(head -5 "$TEMP_FILE" 2>/dev/null || echo "Unable to read temp file")"
              rm -f "$TEMP_FILE" >/dev/null 2>&1
            fi
          else
            # Show error details
            log_error "Failed to decrypt rclone config \(exit status: $DECRYPT_STATUS\)"
            
            # Show what was actually written to temp file for debugging
            if [ -f "$TEMP_FILE" ]; then
              log_error "Content written to temp file: $(head -10 "$TEMP_FILE" 2>/dev/null || echo "Unable to read temp file")"
            fi
            
            rm -f "$TEMP_FILE" >/dev/null 2>&1
            
            # Use backup if available
            if [ -f "${cfg.targetDirectory}/rclone.conf.backup" ]; then
              log_message "Using backup rclone config"
              cp "${cfg.targetDirectory}/rclone.conf.backup" "$TARGET_FILE" >/dev/null 2>&1
            fi
          fi
        else
          log_message "No changes detected in secret file, using existing config"
        fi
      else
        log_error "Secret file not found at $ABSOLUTE_SECRET_FILE"
        log_error "Expected location: $ABSOLUTE_SECRET_FILE"
        log_error "Flake directory contents: $(ls -la "$FLAKE_DIR/modules/agenix/" 2>/dev/null || echo "Directory not accessible")"
      fi
      
      log_message "Completed rclone config decryption"
    '';
  };
}
