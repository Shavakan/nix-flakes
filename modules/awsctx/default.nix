{ config, lib, pkgs, saml2aws, ... }:

with lib;

let
  cfg = config.services.awsctx;
  
  # Define where the repo will be cloned
  repoPath = "${config.home.homeDirectory}/workspace/awsctx";
  
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
    repo = mkOption {
      type = types.str;
      default = "git@github.com:devsisters/awsctx.git";
      description = "The awsctx repository URL";
    };
  };

  config = mkIf cfg.enable {
    # Required dependencies
    home.packages = [ 
      awsLoginAll 
      pkgs.saml2aws
      pkgs.git
      pkgs.openssh
      pkgs.coreutils # For timeout command
    ];
    
    # Clone the repository and set up symlinks during activation
    home.activation.setupAwsctx = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      CONFIG_DIR="$HOME/Library/Application Support/awsctx" 
      CACHE_DIR="$HOME/Library/Caches/awsctx"
      
      # Create the target directory for the repository if it doesn't exist
      mkdir -p $(dirname "${repoPath}")
      
      # Check if SSH agent is running and start it if needed
      if ! ssh-add -l &>/dev/null; then
        # Start SSH agent silently
        eval "$(${pkgs.openssh}/bin/ssh-agent -s)" > /dev/null 2>&1
        log_nix "awsctx" "Started SSH agent for repository operations"
      fi
      
      # Clone the repository if it doesn't exist
      if [ ! -d "${repoPath}" ]; then
        # Create the directory first to ensure we have something to work with
        # even if the clone fails
        mkdir -p "${repoPath}"
        
        # Use explicit path to SSH
        export GIT_SSH="${pkgs.openssh}/bin/ssh"
        
        # Remove the directory so git can create it
        rmdir "${repoPath}" 2>/dev/null || true
        
        # Try to clone silently, redirecting output to avoid noise
        if ! ${pkgs.git}/bin/git clone ${cfg.repo} "${repoPath}" > /dev/null 2>&1; then
          log_nix "awsctx" "Failed to clone repository automatically. This is normal if SSH keys aren't loaded."
          
          # Recreate the directory
          mkdir -p "${repoPath}"
        else
          log_nix "awsctx" "Successfully cloned repository to ${repoPath}"
        fi
      fi
      
      # Create symlink from workspace to Library/Application Support if needed
      if [ ! -L "$CONFIG_DIR" ]; then
        # If it's a directory, back it up
        if [ -d "$CONFIG_DIR" ]; then
          mv "$CONFIG_DIR" "$CONFIG_DIR.bak.$(date +%s)"
        fi
        
        # Create the symlink
        ln -sfn "${repoPath}" "$CONFIG_DIR"
      fi
      
      # Always create the cache directory
      mkdir -p "$CACHE_DIR"
    '';
    
    # Direct shell function implementation
    programs.zsh.initExtra = mkIf (config.programs.zsh.enable or false) ''
      # Add bin directory to PATH for aws-login-all script
      export PATH="${repoPath}/bin:$PATH"
      
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
