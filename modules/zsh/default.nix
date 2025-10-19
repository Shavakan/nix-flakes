{ config, lib, pkgs, zsh-powerlevel10k, zsh-autopair, selectedTheme ? null, ... }:

with lib;

{
  # No longer need powerlevel10k
  # home.packages = with pkgs; [
  #   zsh-powerlevel10k
  # ];

  # Generate a themed Powerlevel10k configuration
  home.file.".p10k.zsh" = {
    # Use text directly instead of a separate file
    text =
      let
        # Read the template file
        templateContent = builtins.readFile ./p10k.zsh;

        # Get colors from the theme
        dirColor = if selectedTheme != null then toString selectedTheme.p10kColors.directory else "33";
        gitCleanColor = if selectedTheme != null then toString selectedTheme.p10kColors.gitClean else "76";
        gitModifiedColor = if selectedTheme != null then toString selectedTheme.p10kColors.gitModified else "214";
        gitUntrackedColor = if selectedTheme != null then toString selectedTheme.p10kColors.gitUntracked else "39";
        themeName = if selectedTheme != null then selectedTheme.name else "default";

        # Apply color replacements
        withColorsContent = builtins.replaceStrings
          [
            "typeset -g POWERLEVEL9K_DIR_FOREGROUND=33"
            "typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=82"
            "typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=220"
            "typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=39"
          ]
          [
            "typeset -g POWERLEVEL9K_DIR_FOREGROUND=${dirColor}"
            "typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=${gitCleanColor}"
            "typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=${gitModifiedColor}"
            "typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=${gitUntrackedColor}"
          ]
          templateContent;

        # Always show kubernetes context with a simpler approach
        finalContent = builtins.replaceStrings
          [ "typeset -g POWERLEVEL9K_KUBECONTEXT_SHOW_ON_COMMAND='kubectl|helm|kubens|kubectx|oc|istioctl|skaffold|stern|k'" ]
          [ "# Always show kubernetes context regardless of command\ntypeset -g POWERLEVEL9K_KUBECONTEXT_ALWAYS_SHOW=true" ]
          withColorsContent;
      in
      ''${finalContent}
      
      # Current theme: ${themeName}
    '';
  };

  # Create a separate file for Kubernetes context styling with additional formatting
  home.file.".p10k-k8s.zsh" = {
    text = ''
      # CUSTOM K8S CONTEXT SETTINGS - ADDED BY NIX
      # Custom kubernetes context format
      typeset -g POWERLEVEL9K_KUBECONTEXT_PREFIX='%F{6}[%f'
      typeset -g POWERLEVEL9K_KUBECONTEXT_SUFFIX='%F{6}]%f'

      # Always include namespace in the prompt
      typeset -g POWERLEVEL9K_KUBECONTEXT_SHOW_DEFAULT_NAMESPACE=true
    '';
  };


  # ZSH Configuration
  programs.zsh = {
    enable = true;

    # Enable features
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # History settings
    history = {
      size = 50000;
      save = 50000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      share = true;
      extended = true;
    };

    # Oh-My-Zsh configuration
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
        "terraform"
        "aws"
        "kubectl"
        "fzf"
      ];

      # We're using powerlevel10k directly, so no theme needed here
      theme = "";
    };

    # Plugins not covered by Oh-My-Zsh
    plugins = [
      {
        # Auto pair brackets, quotes, etc.
        name = "zsh-autopair";
        src = zsh-autopair;
      }
      {
        # Powerlevel10k theme
        name = "powerlevel10k";
        src = zsh-powerlevel10k;
        file = "powerlevel10k.zsh-theme";
      }
    ];

    # Powerlevel10k initialization must come before anything else + environment variables
    initContent = lib.mkMerge [
      (lib.mkBefore ''
        # Ensure USERNAME is defined (sometimes not available in shells)
        export USERNAME="$(whoami)"
        
        # Enable Powerlevel10k instant prompt - simplified version to avoid syntax issues
        if [ -d "$HOME/.cache" ]; then
          p10k_instant_file="$HOME/.cache/p10k-instant-prompt-$(whoami).zsh"
          if [ -r "$p10k_instant_file" ]; then
            source "$p10k_instant_file"
          fi
        fi

        # Initialize Powerlevel10k
        [ -f ~/.p10k.zsh ] && source ~/.p10k.zsh
        
        # Apply custom Kubernetes context styling
        [ -f ~/.p10k-k8s.zsh ] && source ~/.p10k-k8s.zsh
      '')
      ''
        # Force terminal to use colors
        export TERM="xterm-256color"
        export COLORTERM="truecolor"
      
        # Enable colors
        autoload -U colors && colors

        # Ensure oh-my-zsh cache directory has proper permissions
        if [ -d "$HOME/.cache/oh-my-zsh" ]; then
          chmod -R 755 "$HOME/.cache/oh-my-zsh" 2>/dev/null || true
        else
          mkdir -p "$HOME/.cache/oh-my-zsh"
          chmod -R 755 "$HOME/.cache/oh-my-zsh" 2>/dev/null || true
        fi
      
        # Fix oh-my-zsh related issues
        if command -v ripgrep >/dev/null 2>&1; then
          # Create a symlink for ripgrep in case the plugin is missing
          alias rg="ripgrep"
        fi
      
        # Set ZSH completion to use LS_COLORS
        zstyle ':completion:*' list-colors "$LS_COLORS"
      
        # Custom zsh settings
        setopt AUTO_CD
        setopt HIST_IGNORE_SPACE
        setopt EXTENDED_HISTORY
        setopt HIST_EXPIRE_DUPS_FIRST
        setopt HIST_FIND_NO_DUPS
        setopt HIST_REDUCE_BLANKS
        setopt HIST_VERIFY
      
        # Path additions
        export PATH="$PATH:$HOME/.nix-profile/bin:$HOME/.local/bin"
      
        # .NET Core SDK tools
        export PATH="$PATH:$HOME/.dotnet/tools"
      
        # Go configuration
        export GOPATH=$HOME/workspace/go
        export GOBIN=$GOPATH/bin
        export PATH="$PATH:$GOPATH:$GOBIN"
        export GO111MODULE=on
      
        # SAML2AWS
        export SAML2AWS_SESSION_DURATION=43200
        export AWS_SDK_LOAD_CONFIG=1
      
        # Kubernetes
        export KUBECONFIG=$HOME/.kube/config
        export KUBE_CONFIG_PATH=$KUBECONFIG
        # Simplified path to avoid ZSH-specific syntax
        if [ -d "$HOME/.krew/bin" ]; then
          export PATH="$HOME/.krew/bin:$PATH"
        fi
      
        # GPG configuration
        export GPG_TTY=$(tty)
      
        # Start SSH agent
        eval "$(ssh-agent -s)" >/dev/null 2>&1
      
        # Cargo/Rust
        export PATH="$PATH:$HOME/.cargo/bin"
      
        # Source the shared Devsisters script loader 
        if [ -f "$HOME/.devsisters.sh" ]; then
          source "$HOME/.devsisters.sh"
        fi

        # Mode Toggle System
        export CURRENT_MODE="devsisters"  # Default to devsisters mode since devsisters.sh loads by default

        # Mode command with subcommands
        mode() {
          case "$1" in
            personal)
              if [ -f "$HOME/.personal.sh" ]; then
                echo "🏠 Switching to personal mode..."
                export CURRENT_MODE="personal"
                source "$HOME/.personal.sh"
                echo "✓ Personal mode activated"
                echo "🔌 MCP servers will use personal environment variables"
              else
                echo "❌ Personal script not found at $HOME/.personal.sh"
                echo "Make sure your rclone mount is working and personal.sh exists in the cloud storage"
              fi
              ;;
            devsisters)
              echo "💼 Switching to devsisters mode..."
              export CURRENT_MODE="devsisters"
              # Reload shell to clear personal environment and restore devsisters
              exec zsh
              ;;
            *)
              echo "Current mode: $CURRENT_MODE"
              if [ "$CURRENT_MODE" = "devsisters" ]; then
                echo "📍 Devsisters environment is active"
                echo "🔌 MCP servers using devsisters environment variables"
                echo "Use 'mode personal' to switch to personal mode"
              elif [ "$CURRENT_MODE" = "personal" ]; then
                echo "📍 Personal environment is active"
                echo "🔌 MCP servers using personal environment variables"
                echo "Use 'mode devsisters' to switch back to devsisters mode"
              fi
              echo ""
              echo "Available commands:"
              echo "  mode           - Show current mode and MCP status"
              echo "  mode personal  - Switch to personal mode"
              echo "  mode devsisters - Switch to devsisters mode"
              echo "  mcp            - Manage MCP servers"
              ;;
          esac
        }
      
        # Load fzf if installed
        [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
      
        # Python uv configuration
        export UV_SYSTEM_PYTHON=1  # Allow uv to find system Python installations
      
        if command -v podman >/dev/null 2>&1; then
          PODMAN_SOCKET=$(find /var/folders -name "podman-machine-*-api.sock" -type s 2>/dev/null | head -1)
          if [[ -n "$PODMAN_SOCKET" ]]; then
            export DOCKER_HOST="unix://$PODMAN_SOCKET"
          elif [[ -S "/tmp/podman.sock" ]]; then
            export DOCKER_HOST="unix:///tmp/podman.sock"
          fi
        fi
      
        # Initialize uv for faster Python package management
        if command -v uv > /dev/null; then
          eval "$(uv generate-shell-completion zsh)"
        fi
      
        # Setup Ruby gem path and auto-install ecl if using nix ruby
        if command -v ruby >/dev/null 2>&1 && [[ "$(which ruby)" == *"nix"* ]]; then
          # Add gem bin directory to PATH
          export GEM_HOME="$HOME/.gem/ruby/3.3.0"
          export PATH="$GEM_HOME/bin:$PATH"
          
          # Auto-install ecl gem if not found
          if ! command -v ecl >/dev/null 2>&1; then
            echo "📦 Installing ecl gem..."
            gem install ecl >/dev/null 2>&1 && echo "✓ ecl installed successfully" || echo "⚠️ Failed to install ecl"
          fi
        fi
      
        # FZF configuration for better search experience
        # Using direct path for fzf-share instead of ZSH array access
        if command -v fzf-share > /dev/null 2>&1; then
          source "$(fzf-share)/key-bindings.zsh"
          source "$(fzf-share)/completion.zsh"
        fi
      
        # Better kubectl completion and functions
        if command -v kubectl >/dev/null; then
          source <(kubectl completion zsh)
        
          # Kubernetes helper functions as direct functions (no aliases)
          # Basic kubectl shortcuts as functions
          function kgp() { kubectl get pods "$@"; }
          function kgn() { kubectl get nodes "$@"; }
          function kge() { kubectl get events "$@"; }
          function kgs() { kubectl get services "$@"; }
          function kgd() { kubectl get deployments "$@"; }
          function kdp() { kubectl describe pods "$@"; }
          function kdn() { kubectl describe nodes "$@"; }
        
          # Advanced kubectl functions
          function kgpn() {
            kubectl get pods | grep "$1"
          }
        
          function kdpn() {
            POD=$(kubectl get pods | grep "$1" | awk '{print $1}' | head -n 1)
            if [ -n "$POD" ]; then
              kubectl describe pod "$POD"
            else
              echo "No pod found matching '$1'"
            fi
          }
        
          function kln() {
            POD=$(kubectl get pods | grep "$1" | awk '{print $1}' | head -n 1)
            if [ -n "$POD" ]; then
              shift
              kubectl logs -f "$POD" "$@"
            else
              echo "No pod found matching '$1'"
            fi
          }
        
          function ken() {
            POD=$(kubectl get pods | grep "$1" | awk '{print $1}' | head -n 1)
            if [ -n "$POD" ]; then
              shift
              kubectl exec -it "$POD" "$@" -- /bin/sh
            else
              echo "No pod found matching '$1'"
            fi
          }
        
          function kpfn() {
            if [ $# -lt 2 ]; then
              echo "Usage: kpfn <pod-name> <local-port>:<remote-port>"
              return 1
            fi
          
            POD=$(kubectl get pods | grep "$1" | awk '{print $1}' | head -n 1)
            if [ -n "$POD" ]; then
              shift
              kubectl port-forward "$POD" "$@"
            else
              echo "No pod found matching '$1'"
            fi
          }
        
          function kresources() {
            kubectl top pod "$@"
          }
        
          function knode-resources() {
            kubectl top node "$@"
          }
        
          function krestart() {
            kubectl rollout restart deployment "$1"
          }
        
          function kwatch() {
            watch kubectl get pods "$@"
          }
        
          function kapply() {
            kubectl apply -f "$1" && kubectl get pods -w
          }
        
          function kenv() {
            if [ $# -eq 2 ]; then
              kubectl config use-context "$1" && kubectl config set-context --current --namespace="$2"
              echo "Switched to context '$1' and namespace '$2'"
            elif [ $# -eq 1 ]; then
              kubectl config use-context "$1"
              echo "Switched to context '$1'"
            else
              echo "Current context: $(kubectl config current-context)"
              echo "Current namespace: $(kubectl config view --minify --output 'jsonpath={..namespace}')"
              echo ""
              echo "Available contexts:"
              kubectl config get-contexts
            fi
          }
        fi
      ''
    ];

    # Shell aliases
    shellAliases = {
      # ls aliases with color by default
      ls = "ls --color=auto"; # GNU ls with colors
      ll = "ls -la --color=auto"; # Long listing
      la = "ls -A --color=auto"; # All files except . and ..
      l = "ls -CF --color=auto"; # Columnar format with file indicators
      lh = "ls -lh --color=auto"; # Human-readable sizes
      lt = "ls -lt --color=auto"; # Sort by time, newest first
      # Directory navigation
      cdw = "cd $HOME/workspace/ && ls";

      # Shell reload
      reload-shell = "source ~/.zshrc && source ~/.p10k.zsh && source ~/.p10k-k8s.zsh && echo 'Using theme: ${if selectedTheme != null then selectedTheme.name else "default"}'";

      # Git aliases
      gb = "echo 'git branch' && git branch";
      gba = "echo 'git branch -a' && git branch -a";
      gs = "echo 'git status' && git status";
      gsl = "echo 'git stash list' && git stash list";
      gsp = "echo 'git stash pop' && git stash pop";
      gd = "echo 'git diff' && git diff";
      gds = "echo 'git diff --staged' && git diff --staged";
      gfp = "echo 'git fetch --prune' && git fetch --prune && git branch -r | awk '{print $1}' | egrep -v -f /dev/fd/0 <(git branch -vv | grep origin) | awk '{print $1}' | xargs git branch -d";
      gfpdr = "echo 'git fetch --prune --dry-run' && git fetch --prune --dry-run";
      gsur = "echo 'git submodule update --recursive' && git submodule update --recursive";
      grhh = "echo 'git reset --hard HEAD' && git reset --hard HEAD";
      gprr = "echo 'git pull --rebase' && git pull --rebase";

      # Podman aliases
      pp = "echo 'podman ps' && podman ps";
      psp = "echo 'podman system prune' && podman system prune";
      pc = "podman-compose";

      # Podman machine management
      podman-start = "podman machine start";
      podman-stop = "podman machine stop";
      podman-status = "podman machine list";
      podman-socket-info = "podman system connection list";

      # Docker compatibility alias for podman
      docker = "podman";

      # Terraform
      tflock = "echo 'terraform providers lock -platform=windows_amd64 -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64' && terraform providers lock -platform=windows_amd64 -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64";

      # Kubernetes - keeping only the simple ones that won't cause conflicts
      k = "kubectl";
      kg = "kubectl get";
      ka = "kubectl apply -f";
      kd = "kubectl describe";
      krm = "kubectl delete";
      kl = "kubectl logs";
      klf = "kubectl logs -f";
      ke = "kubectl exec -it";
      kc = "kubectl config current-context";
      kcc = "kubectl config get-contexts";
      ksc = "kubectl config use-context";

      # Neovim
      vim = "nvim";
      vi = "nvim";
      vimdiff = "nvim -d";

      # System tools
      mtr = "sudo ${pkgs.mtr}/bin/mtr";

      # Python tools - use uv instead of pip
      pip = "uv pip";
    };
  };

  # Enable other shell integrations

  # Remove the custom K8s context display activation script since we're using a file approach
  # home.activation.addKubernetesContextStyles = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   # This has been replaced with a direct file approach
  # '';


  # fzf for fuzzy finding
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --exclude .git";
    defaultOptions = [ "--height 40%" "--layout=reverse" "--border" ];
    fileWidgetCommand = "fd --type f --hidden --exclude .git";
    fileWidgetOptions = [ "--preview 'bat --color=always --style=numbers --line-range=:500 {}'" ];
    changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    changeDirWidgetOptions = [ "--preview 'ls -la {}'" ];
  };

  # direnv for environment management
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };
}
