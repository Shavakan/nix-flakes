{ config, lib, pkgs, zsh-powerlevel10k, zsh-autopair, ... }:

with lib;

{
  # Install powerlevel10k directly in the system packages to ensure it's available
  home.packages = with pkgs; [
    zsh-powerlevel10k
  ];

  # Create p10k.zsh configuration file directly in home directory
  home.file.".p10k.zsh".source = ./p10k.zsh;

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
      
      # Leave theme empty in oh-my-zsh - we'll load powerlevel10k directly
      theme = "";
    };

    # Plugins not covered by Oh-My-Zsh
    plugins = [
      {
        # Auto pair brackets, quotes, etc.
        name = "zsh-autopair";
        src = zsh-autopair;
      }
    ];

    # Init powerlevel10k first in zshrc, as recommended in the thread
    initExtraFirst = ''
      # Source powerlevel10k from the system
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      
      # Load p10k config
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
    '';

    # Environment variables
    initExtra = ''
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
      
      # Initialize LS_COLORS to distinguish between files and directories
      export CLICOLOR=1
      export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd
      
      # Custom zsh settings
      setopt AUTO_CD
      setopt HIST_IGNORE_SPACE
      setopt EXTENDED_HISTORY
      setopt HIST_EXPIRE_DUPS_FIRST
      setopt HIST_FIND_NO_DUPS
      setopt HIST_REDUCE_BLANKS
      setopt HIST_VERIFY
      
      # Path additions
      export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"
      
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
      export PATH="''${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
      
      # GPG configuration
      export GPG_TTY=$(tty)
      
      # Use Apple's SSH agent instead of GPG for SSH authentication on macOS
      # This provides better integration with macOS keychain
      unset SSH_AUTH_SOCK
      unset SSH_AGENT_PID
      
      # Cargo/Rust
      export PATH="$PATH:$HOME/.cargo/bin"
      
      # Source the shared Devsisters script loader 
      if [ -f "$HOME/.devsisters.sh" ]; then
        source "$HOME/.devsisters.sh"
      fi
      
      # Load fzf if installed
      [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
      
      # Python uv configuration
      export UV_SYSTEM_PYTHON=1  # Allow uv to find system Python installations
      
      # Initialize uv for faster Python package management
      if command -v uv > /dev/null; then
        eval "$(uv generate-shell-completion zsh)"
      fi
      
      # FZF configuration for better search experience
      if [ -n "''${commands[fzf-share]}" ]; then
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
    '';

    # Shell aliases
    shellAliases = {
      # Directory navigation
      cdw = "cd $HOME/workspace/ && ls";

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

      # Terraform
      tpl = "echo 'terraform providers lock -platform=windows_amd64 -platform=linux_amd64 -platform=darwin_amd64 -platform=darwin_arm64' && terraform providers lock -platform=windows_amd64 -platform=linux_amd64 -platform=darwin_amd64 -platform=darwin_arm64";

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
