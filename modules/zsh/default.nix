{ config, lib, pkgs, zsh-powerlevel10k, zsh-autopair, ... }:

with lib;

{
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
        "ripgrep"
      ];
      
      # Using Powerlevel10k theme if it was detected
      theme = "powerlevel10k/powerlevel10k";
    };
    
    # Plugins not covered by Oh-My-Zsh
    plugins = [
      {
        # Powerlevel10k
        name = "powerlevel10k";
        src = zsh-powerlevel10k;
        file = "powerlevel10k.zsh-theme";
      }
      {
        # Auto pair brackets, quotes, etc.
        name = "zsh-autopair";
        src = zsh-autopair;
      }
    ];
    
    # Environment variables
    initExtraBeforeCompInit = ''
      # Check if p10k config exists
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
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
      
      # Kubernetes
      k = "kubectl";
      kg = "kubectl get";
      kgp = "kubectl get pods";
      kgn = "kubectl get nodes";
      kge = "kubectl get events";
      kd = "kubectl describe";
      kdp = "kubectl describe pods";
      kdn = "kubectl describe nodes";
      kl = "kubectl logs";
      
      # Neovim
      vim = "nvim";
      vi = "nvim";
      vimdiff = "nvim -d";
      
      # System tools
      mtr = "sudo ${pkgs.mtr}/bin/mtr";
      
      # Python tools - use uv instead of pip
      pip = "uv pip";
    };
    
    # Additional Zsh configuration
    initExtra = ''
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
      
      # Better kubectl completion
      if command -v kubectl >/dev/null; then
        source <(kubectl completion zsh)
      fi
    '';
  };
  
  # Enable other shell integrations
  
  # fzf for fuzzy finding
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --exclude .git";
    defaultOptions = ["--height 40%" "--layout=reverse" "--border"];
    fileWidgetCommand = "fd --type f --hidden --exclude .git";
    fileWidgetOptions = ["--preview 'bat --color=always --style=numbers --line-range=:500 {}'"];
    changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    changeDirWidgetOptions = ["--preview 'ls -la {}'"]; 
  };
  
  # direnv for environment management
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };
  
  # Skip creating p10k.zsh file since you already have one
  # home.file.".p10k.zsh" = { ... };

}
