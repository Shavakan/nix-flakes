{ config, pkgs, lib, ... }@args:

{
  # Import configurations
  imports = [
    ./mcp-servers.nix
    ./modules/rclone.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should manage
  home = {
    username = "shavakan";
    homeDirectory = "/Users/shavakan";

    # Set language for shell sessions managed by home-manager
    language = {
      base = "en_US.UTF-8";
    };

    # Packages to install to the user profile
    packages = with pkgs; [
      # Development languages and tools
      terraform

      # Cloud tools
      kubectl
      awscli2
      google-cloud-sdk

      # GPG
      gnupg

      # Secrets management
      agenix

      # Misc
      direnv
    ];

    # This value determines the Home Manager release compatibility
    stateVersion = "24.11";
  };

  # Configure GPG to use terminal for passphrase entry and enable SSH support
  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${pkgs.gnupg}/bin/pinentry
    allow-loopback-pinentry
    no-grab
    enable-ssh-support
  '';

  # Configure GPG to use loopback
  home.file.".gnupg/gpg.conf".text = ''
    use-agent
    pinentry-mode loopback
  '';

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Disable showing news on update
  news.display = "silent";

  # Enable and configure Git
  programs.git = {
    enable = true;
    userName = "ChangWon Lee";
    userEmail = "cs.changwon.lee@gmail.com";

    extraConfig = {
      core = {
        editor = "nvim";
        excludesfile = "~/.gitignore_global";
      };
      user.signingkey = "1193AD54623C8450";
      merge = {
        tool = "vimdiff";
      };
      mergetool = {
        vimdiff.cmd = "nvim -d $LOCAL $REMOTE $MERGED -c '$wincmd w' -c '$wincmd J'";
        keepBackup = false;
      };
      filter.lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };
      commit.gpgsign = true;
      gpg.program = "gpg";
      push = {
        autoSetupRemote = true;
        default = "current";
      };
      alias = {
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
      url = {
        "https://".insteadOf = "git://";
      };
    };
  };

  # Create global gitignore file
  home.file.".gitignore_global".text = ''
    # Go delve test file
    debug.test

    # Vim swap files
    *.sw[op]

    # Vim pylint plugin
    .ropeproject/

    # macOS
    .DS_Store

    # VS Code
    .vscode/

    # IntelliJ
    .idea/

    # Terraform
    .tool-versions
    .terraform/

    # direnv
    .envrc
  '';

  # Configure ZSH
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;

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

    # History settings
    history = {
      size = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      share = true;
    };

    # Extra config
    initExtra = ''
      # Custom zsh settings
      setopt AUTO_CD
      setopt HIST_IGNORE_SPACE

      # Path additions
      export PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH"

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
      export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
      gpgconf --launch gpg-agent

      # Cargo/Rust
      export PATH="$PATH:$HOME/.cargo/bin"

      # oh-my-zsh plugins and theme (if installed)
      if [ -d "$HOME/.oh-my-zsh" ]; then
        export ZSH="$HOME/.oh-my-zsh"
        ZSH_THEME="powerlevel10k/powerlevel10k"
        plugins=(git terraform)
        source $ZSH/oh-my-zsh.sh

        # p10k
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      fi

      # Optional: Load fzf if installed
      [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

      # Python uv configuration
      export UV_SYSTEM_PYTHON=1  # Allow uv to find system Python installations

      # Initialize uv for faster Python package management
      if command -v uv > /dev/null; then
        eval "$(uv generate-shell-completion zsh)"
      fi
    '';
  };

  # Configure tmux
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1;
    terminal = "screen-256color";
    escapeTime = 0;
    historyLimit = 10000;

    extraConfig = ''
      # Additional tmux configuration
      set -g mouse on
      set -g status-style "bg=black,fg=white"

      # Pane navigation like vim
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Synchronize panes
      bind-key sp set-window-option synchronize-panes\; display-message "synchromize-panes is now #{?pane_synchronized,on,off}"
    '';
  };

  # Configure neovim - using only the home-manager module to avoid conflicts
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    extraConfig = ''
      "" Shavakan's .vimrc file 
      "" Adapted for neovim configuration

      scripte utf-8

      syn enable
      syn sync fromstart
      filetype plugin indent on

      " AUTOCMD
      autocmd BufRead,BufNewFile *.capnp set filetype=capnp
      autocmd BufRead,BufNewFile *.tf set filetype=terraform
      autocmd FileType gitcommit DiffGitCached | wincmd L | wincmd p

      if has("autocmd")
        aug vimrc
        au!

        " filetype-specific configurations
        au FileType python setl ts=8 sw=4 sts=4 et
        au FileType yaml setl ts=8 sw=2 sts=2 et
        au FileType sh setl ts=2 sw=4 sts=4 et
        au FileType c setl ts=8 sw=4 sts=4 et
        au FileType html setl ts=8 sw=2 sts=2 et
        au FileType css setl ts=8 sw=4 sts=4 et
        au FileType javascript setl ts=2 sw=2 sts=2 et
        au FileType terraform setl ts=8 sw=2 sts=2 et
        au FileType cpp setl ts=8 sw=4 sts=4 et
        au FileType java setl ts=4 sw=4 sts=0 noet
        au FileType php setl ts=8 sw=4 sts=4 et
        au FileType asp setl ts=8 sw=4 sts=4 et
        au FileType jsp setl ts=8 sw=4 sts=4 et
        au FileType ruby setl ts=8 sw=4 sts=4 et
        au FileType capnp setl ts=2 sw=2 sts=2 et
        au FileType jsx sync fromstart ts=2 sw=2 sts=2 et
        au FileType vue syntax sync fromstart ts=2 sw=2 sts=2 et
        au FileType text setl tw=80

        " restore cursor position when the file has been read
        au BufReadPost *
                \ if line("'\"") > 0 && line("'\"") <= line("$") |
                \   exe "norm g`\"" |
                \ endif
        aug END
      endif

      " Editor settings
      set mouse=a                             " -- mouse cursor on
      set noet bs=2 ts=4 sw=8 sts=0           " -- tabstop
      set noai nosi hls is ic cf ws scs magic " -- search
      set nu ru sc wrap ls=2 lz               " -- appearance
      set expandtab                           " -- tab as spaces
      set clipboard=unnamed                   " -- clipboard usage on macOS

      " encoding and file format
      set fenc=utf-8 ff=unix ffs=unix,dos,mac
      set fencs=utf-8,cp949,cp932,euc-jp,shift-jis,big5,latin2,ucs2-le

      " Configuration Variables
      let g:javascript_plugin_jsdoc = 1
      let g:javascript_plugin_flow = 1

      " vim-terraform
      let g:terraform_align=1
      let g:terraform_remap_spacebar=1
      autocmd FileType terraform setlocal commentstring=#%s
    '';

    plugins = with pkgs.vimPlugins; [
      vim-nix
      vim-surround
      vim-commentary
      vim-fugitive
      vim-terraform
      fzf-vim
      nord-vim
    ];
  };

  # Configure direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Configure fzf
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Configure rclone with agenix
  services.rclone = {
    enable = true;
    configFile = ./secrets/rclone.conf.age;
  };
}
