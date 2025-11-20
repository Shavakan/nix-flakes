{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.awsctx;

  repoPath = "${config.home.homeDirectory}/workspace/awsctx";

  getXdgDirs = pkgs.writeShellScript "get-xdg-dirs" ''
    os="$(uname -s)"
    
    case "$os" in
      Darwin*)
        echo "CONFIG_DIR=\"''${XDG_CONFIG_HOME:-$HOME/Library/Application\\ Support}/awsctx\""
        echo "CACHE_DIR=\"''${XDG_CACHE_HOME:-$HOME/Library/Caches}/awsctx\""
        ;;
      Linux*)
        echo "CONFIG_DIR=\"''${XDG_CONFIG_HOME:-$HOME/.config}/awsctx\""
        echo "CACHE_DIR=\"''${XDG_CACHE_HOME:-$HOME/.cache}/awsctx\""
        ;;
      *)
        echo "Unsupported OS: $os" >&2
        exit 1
        ;;
    esac
  '';

  awsLoginAll = pkgs.writeShellScriptBin "aws-login-all" ''
    #!/usr/bin/env bash
    set -e

    eval "$(${getXdgDirs})"

    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

    if [ -z "''${SAML2AWS_PASSWORD}" ]; then
      read -s -p "Password: " SAML2AWS_PASSWORD; export SAML2AWS_PASSWORD; echo
    fi
    read -p "OTP: " SAML2AWS_MFA_TOKEN; export SAML2AWS_MFA_TOKEN

    saml_cache="$(mktemp)"
    trap "rm -f ''${saml_cache}" EXIT

    echo "Authenticating and getting SAML response..."
    list_roles="$(${pkgs.saml2aws}/bin/saml2aws --disable-keychain --skip-prompt list-roles --cache-saml --cache-file "''${saml_cache}")"
    
    # Process each role
    for role in $(echo "''${list_roles}" | grep "arn:aws:iam::" | cut -d' ' -f1); do
      role_name="''${role##*/}"
      echo "Processing role: ''${role_name}"
      echo "Logging in to ''${role}..."
      
      # Use a separate shell to avoid AWS_SHARED_CREDENTIALS_FILE persisting
      (
        mkdir -p "''${CACHE_DIR}"
        ${pkgs.saml2aws}/bin/saml2aws --disable-keychain --skip-prompt login \
          --force \
          --role "''${role}" \
          --session-duration 43200 \
          --cache-saml \
          --cache-file "''${saml_cache}"
        
        # If login was successful, copy the credentials file to our destination
        if [ $? -eq 0 ]; then
          # Find the credentials file that was just created
          if [ -f ~/.aws/credentials ]; then
            echo "Copying credentials to ''${CACHE_DIR}/''${role_name}.credentials"
            cp ~/.aws/credentials "''${CACHE_DIR}/''${role_name}.credentials"
          else
            echo "Could not find credentials file after login"
          fi
        else
          echo "Login failed for ''${role}"
        fi
      )
    done
    
    echo "All roles processed successfully."
  '';

  awsctx = pkgs.writeShellScriptBin "awsctx" ''
    #!/usr/bin/env bash
    set -e

    ctx="$1"

    if [ -z "$ctx" ]; then
      echo "Usage: awsctx <context>"
      exit 1
    fi

    # Source XDG directories - this sets CONFIG_DIR and CACHE_DIR variables
    eval "$(${getXdgDirs})"

    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

    export AWSCTX="$ctx"
    export AWS_SHARED_CREDENTIALS_FILE="$CACHE_DIR/$ctx.credentials"
    export AWS_CONFIG_FILE="$CONFIG_DIR/profiles/$ctx.config"

    echo "Activated AWS context: $ctx"
    echo "Using credentials: $AWS_SHARED_CREDENTIALS_FILE"
    echo "Using config: $AWS_CONFIG_FILE"

    if [ $# -gt 1 ]; then
      shift
      exec "$@"
    fi
  '';

  bashCompletion = pkgs.writeTextFile {
    name = "awsctx-completion";
    destination = "/share/bash-completion/completions/awsctx";
    text = ''
      #!/usr/bin/env bash
      
      function _awsctx_get_directory() {
        local type="$1"

        case "$(uname -s)" in
          Darwin*)
            [ -z "''${XDG_CONFIG_HOME}" ] && local XDG_CONFIG_HOME="''${HOME}/Library/Application Support"
            [ -z "''${XDG_CACHE_HOME}" ] && local XDG_CACHE_HOME="''${HOME}/Library/Caches"
            ;;
          Linux*)
            [ -z "''${XDG_CONFIG_HOME}" ] && local XDG_CONFIG_HOME="''${HOME}/.config"
            [ -z "''${XDG_CACHE_HOME}" ] && local XDG_CACHE_HOME="''${HOME}/.cache"
            ;;
          *)
            echo "Unsupported OS: $(uname -s)" >&2
            return 1
            ;;
        esac

        local CONFIG_DIR="''${XDG_CONFIG_HOME}/awsctx"
        local CACHE_DIR="''${XDG_CACHE_HOME}/awsctx"

        case "''${type}" in
          config)
            echo "''${CONFIG_DIR}"
            ;;
          cache)
            echo "''${CACHE_DIR}"
            ;;
          *)
            echo "Unsupported type: ''${type}" >&2
            return 1
            ;;
        esac
      }
      
      _awsctx() {
        local CACHE_DIR=$(_awsctx_get_directory cache)
        local current="''${COMP_WORDS[''${COMP_CWORD}]}"
        local credential
        
        test "''${COMP_CWORD}" -gt 1 && return

        mkdir -p "$CACHE_DIR" 2>/dev/null || true
        
        COMPREPLY=()
        for credential in $(find "''${CACHE_DIR}" -name "''${current}*.credentials" 2>/dev/null); do
          credential="''${credential##*/}"
          COMPREPLY+=("''${credential%.credentials}")
        done
        
        return 0
      }
      
      complete -F _awsctx awsctx
    '';
  };

  # Create a completion script for zsh
  zshCompletion = pkgs.writeTextFile {
    name = "awsctx-zsh-completion";
    destination = "/share/zsh/site-functions/_awsctx";
    text = ''
      #compdef awsctx
      
      _awsctx_get_directory() {
        local type="$1"
        
        case "$(uname -s)" in
          Darwin*)
            [[ -z "$XDG_CONFIG_HOME" ]] && local XDG_CONFIG_HOME="$HOME/Library/Application Support"
            [[ -z "$XDG_CACHE_HOME" ]] && local XDG_CACHE_HOME="$HOME/Library/Caches"
            ;;
          Linux*)
            [[ -z "$XDG_CONFIG_HOME" ]] && local XDG_CONFIG_HOME="$HOME/.config"
            [[ -z "$XDG_CACHE_HOME" ]] && local XDG_CACHE_HOME="$HOME/.cache"
            ;;
          *)
            echo "Unsupported OS: $(uname -s)" >&2
            return 1
            ;;
        esac
        
        local CONFIG_DIR="$XDG_CONFIG_HOME/awsctx"
        local CACHE_DIR="$XDG_CACHE_HOME/awsctx"
        
        case "$type" in
          config)
            echo "$CONFIG_DIR"
            ;;
          cache)
            echo "$CACHE_DIR"
            ;;
          *)
            echo "Unsupported type: $type" >&2
            return 1
            ;;
        esac
      }
      
      _awsctx() {
        local CACHE_DIR
        CACHE_DIR=$(_awsctx_get_directory cache)
        
        mkdir -p "$CACHE_DIR" 2>/dev/null || true
        
        _files -W "$CACHE_DIR" -g "*.credentials(:r)"
      }
      
      _awsctx "$@"
    '';
  };

  # Create a completion script for fish
  fishCompletion = pkgs.writeTextFile {
    name = "awsctx-fish-completion";
    destination = "/share/fish/vendor_completions.d/awsctx.fish";
    text = ''
      function __awsctx_get_contexts
        switch (uname -s)
          case 'Darwin*'
            test -z "$XDG_CONFIG_HOME"; and set -f XDG_CONFIG_HOME "$HOME/Library/Application Support"
            test -z "$XDG_CACHE_HOME"; and set -f XDG_CACHE_HOME "$HOME/Library/Caches"
          case 'Linux*'
            test -z "$XDG_CONFIG_HOME"; and set -f XDG_CONFIG_HOME "$HOME/.config"
            test -z "$XDG_CACHE_HOME"; and set -f XDG_CACHE_HOME "$HOME/.cache"
          case '*'
            echo "Unsupported OS: $(uname -s)"
            return 1
        end

        set -f CONFIG_DIR "$XDG_CONFIG_HOME/awsctx"
        set -f CACHE_DIR "$XDG_CACHE_HOME/awsctx"

        mkdir -p "$CACHE_DIR" 2>/dev/null
        
        find $CACHE_DIR -name '*.credentials' 2>/dev/null | while read -l credential
          set -l credential (string split -r -m1 -f2 / $credential)
          string replace '.credentials' "" $credential
        end
      end

      complete -c awsctx -x -a "(__awsctx_get_contexts)"
    '';
  };

  # Create a comprehensive package that includes all the tools
  awsctxPackage = pkgs.symlinkJoin {
    name = "awsctx";
    paths = [
      awsctx
      awsLoginAll
      bashCompletion
      zshCompletion
      fishCompletion
    ];
  };

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
    home.packages = [
      awsctxPackage
      pkgs.saml2aws
      pkgs.git
      pkgs.openssh
      pkgs.coreutils
    ];

    # Clone the repository and set up symlinks during activation
    home.activation.setupAwsctx = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      eval "$(${getXdgDirs})"

      log_nix "awsctx" "CONFIG_DIR: $CONFIG_DIR, CACHE_DIR: $CACHE_DIR"

      mkdir -p "$(dirname "${repoPath}")"

      # Check if SSH agent is running and start it if needed
      if ! ssh-add -l &>/dev/null; then
        eval "$(${pkgs.openssh}/bin/ssh-agent -s)" >/dev/null 2>&1
        log_nix "awsctx" "Started SSH agent for repository operations"
      fi

      if [ ! -d "${repoPath}" ]; then
        # Create the directory first to ensure we have something to work with
        # even if the clone fails
        mkdir -p "${repoPath}"

        export GIT_SSH="${pkgs.openssh}/bin/ssh"

        # Remove the directory so git can create it
        rmdir "${repoPath}" 2>/dev/null || true

        if ! ${pkgs.git}/bin/git clone ${cfg.repo} "${repoPath}" > /dev/null 2>&1; then
          log_nix "awsctx" "Failed to clone repository automatically. This is normal if SSH keys aren't loaded."

          mkdir -p "${repoPath}"
        else
          log_nix "awsctx" "Successfully cloned repository to ${repoPath}"
        fi
      fi

      # Use quotes to handle spaces in paths
      mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

      if [ -d "${repoPath}/profiles" ]; then
        mkdir -p "$CONFIG_DIR/profiles"

        for config_file in "${repoPath}"/profiles/*.config; do
          if [ -f "$config_file" ]; then
            base_name=$(basename "$config_file")
            cp -f "$config_file" "$CONFIG_DIR/profiles/$base_name"
          fi
        done
      fi
    '';
  };
}
