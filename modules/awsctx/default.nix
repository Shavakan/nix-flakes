{ config, lib, pkgs, saml2aws, ... }:

with lib;

let
  cfg = config.services.awsctx;
  
  # Source repository path
  sourcePath = "/Users/shavakan/workspace/awsctx";
  repoUrl = "https://github.com/devsisters/awsctx.git";
  
  # Create the aws-login-all script as a proper Nix package
  awsLoginAll = pkgs.writeShellScriptBin "aws-login-all" ''
    #!/usr/bin/env bash

    function main() {
      load_os_environments || return 1
      prepare_directory || return 1
      do_login
    }

    function load_os_environments() {
      local os="$(uname -s)"

      case "''${os}" in
        Darwin*)
          [ -z "''${XDG_CONFIG_HOME}" ] && local XDG_CONFIG_HOME="''${HOME}/Library/Application Support"
          [ -z "''${XDG_CACHE_HOME}" ] && local XDG_CACHE_HOME="''${HOME}/Library/Caches"
          ;;
        Linux*)
          [ -z "''${XDG_CONFIG_HOME}" ] && local XDG_CONFIG_HOME="''${HOME}/.config"
          [ -z "''${XDG_CACHE_HOME}" ] && local XDG_CACHE_HOME="''${HOME}/.cache"
          ;;
        *)
          echo "Unsupported OS: ''${os}"
          exit 1
          ;;
      esac

      readonly CONFIG_DIR="''${XDG_CONFIG_HOME}/awsctx"
      readonly CACHE_DIR="''${XDG_CACHE_HOME}/awsctx"
    }

    function prepare_directory() {
      mkdir -p "''${CONFIG_DIR}" "''${CACHE_DIR}" || return 1
    }

    function do_login() {
      local saml_cache list_roles role
      local child_pids=()
      local child_error="false"

      saml_cache="$(mktemp)" || return 1
      trap "rm ''${saml_cache}" EXIT

      if [ -z "''${SAML2AWS_PASSWORD}" ]; then
        read -s -p "Password: " SAML2AWS_PASSWORD; export SAML2AWS_PASSWORD; echo
      fi
      read -p "OTP: " SAML2AWS_MFA_TOKEN; export SAML2AWS_MFA_TOKEN

      list_roles="$(${pkgs.saml2aws}/bin/saml2aws --disable-keychain --skip-prompt list-roles --cache-saml --cache-file "''${saml_cache}")" || return 2

      for role in $(echo "''${list_roles}" | tail -n+2); do
        local role_name="''${role##*/}"
        ${pkgs.saml2aws}/bin/saml2aws --disable-keychain --skip-prompt login --force --role "''${role}" --session-duration 43200 --cache-saml --cache-file "''${saml_cache}" --credentials-file "''${CACHE_DIR}/''${role_name}.credentials" >/dev/null &
        child_pids+=($!)
      done

      for pid in "''${child_pids[@]}"; do
        wait "''${pid}" || child_error="true"
      done

      test "''${child_error}" == "true" && return 3 || return 0
    }

    main "$@"
  '';

in
{
  options.services.awsctx = {
    enable = mkEnableOption "awsctx AWS profile context switcher";
  };

  config = mkIf cfg.enable {
    # Required dependencies
    home.packages = [ 
      awsLoginAll 
      pkgs.saml2aws
      pkgs.git
      pkgs.coreutils # For timeout command
    ];
    
    # Create required directories and sync profiles
    home.activation.setupAwsctx = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Create required directories for awsctx
      CONFIG_DIR="$HOME/Library/Application Support/awsctx" 
      CACHE_DIR="$HOME/Library/Caches/awsctx"
      mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
      
      # Check if the repository directory exists, assuming it's already been set up
      if [ -d "${sourcePath}" ]; then
        log_nix "awsctx" "Found existing awsctx repository at ${sourcePath}"
        
        # Only attempt to update if it's a git repository and doesn't have local changes
        if [ -d "${sourcePath}/.git" ] && ! ${pkgs.git}/bin/git -C "${sourcePath}" status --porcelain 2>/dev/null | grep -q .; then
          # Attempt a quick update, but don't worry if it fails - use existing version
          log_nix "awsctx" "Attempting to update existing repository"
          if ${pkgs.coreutils}/bin/timeout 5 ${pkgs.git}/bin/git -C "${sourcePath}" pull --ff-only >/dev/null 2>&1; then
            log_nix "awsctx" "Successfully updated awsctx repository"
          else
            log_nix "awsctx" "Update skipped, using existing version"
          fi
        else
          log_nix "awsctx" "Repository has local changes, skipping update"
        fi
      else
        # This is a fallback case, as the repository should already exist
        log_nix "awsctx" "Expected repository not found at ${sourcePath}"
        echo "Warning: awsctx repository not found at ${sourcePath}"
      fi
      
      # Clear any existing config files to avoid conflicts
      rm -f "$CONFIG_DIR"/*.config
      
      # Create symlinks for config files (not copies) to maintain live updates
      if [ -d "${sourcePath}/profiles" ]; then
        for config_file in ${sourcePath}/profiles/*.config; do
          if [ -f "$config_file" ]; then
            basename=$(basename "$config_file")
            ln -sf "$config_file" "$CONFIG_DIR/$basename"
          fi
        done
      fi
    '';
    
    # Direct shell function implementation
    programs.zsh.initExtra = mkIf (config.programs.zsh.enable or false) ''
      # Add bin directory to PATH for aws-login-all script
      export PATH="${sourcePath}/bin:$PATH"
      
      # awsctx function - direct implementation
      function awsctx() {
        local ctx="$1"
        
        # Set up directories
        [[ -z "$XDG_CONFIG_HOME" ]] && local XDG_CONFIG_HOME="$HOME/Library/Application Support"
        [[ -z "$XDG_CACHE_HOME" ]] && local XDG_CACHE_HOME="$HOME/Library/Caches"
        
        local CONFIG_DIR="$XDG_CONFIG_HOME/awsctx"
        local CACHE_DIR="$XDG_CACHE_HOME/awsctx"
        
        # Set environment variables
        export AWSCTX="$ctx"
        export AWS_SHARED_CREDENTIALS_FILE="$CACHE_DIR/$ctx.credentials"
        export AWS_CONFIG_FILE="$CONFIG_DIR/$ctx.config"
      }
      
      # Completion function for awsctx
      function _awsctx() {
        [[ -z "$XDG_CACHE_HOME" ]] && local XDG_CACHE_HOME="$HOME/Library/Caches"
        local CACHE_DIR="$XDG_CACHE_HOME/awsctx"
        _files -W "$CACHE_DIR" -g "*.credentials(:r)"
      }
      compdef _awsctx awsctx
    '';
  };
}
