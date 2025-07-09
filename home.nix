{ config, pkgs, lib, hostname, zsh-powerlevel10k, zsh-autopair, vim-nord, vim-surround, vim-commentary, vim-easy-align, fzf-vim, vim-fugitive, vim-nix, vim-terraform, vim-go, saml2aws, ... }@args:

{
  imports = [
    ./modules/themes
    ./modules/ls-colors
    ./modules/rclone
    ./modules/awsctx
    ./modules/git
    ./modules/neovim
    ./modules/zsh
    ./modules/claude
    ./modules/vscode
    ./modules/cargo
    ./modules/iterm2
    ./modules/spotlight
    ./modules/podman
  ];

  # Home Manager needs a bit of information about you and the paths it should manage
  home = {
    username = "shavakan";
    homeDirectory = "/Users/shavakan";

    # Set language for shell sessions managed by home-manager
    language = {
      base = "en_US.UTF-8";
    };

    # Common logging framework for all activation scripts
    activation.setupLogging = lib.hm.dag.entryBefore [ ] ''
      # Create log directory
      export NIX_LOG_DIR="$HOME/nix-flakes/logs"
      mkdir -p "$NIX_LOG_DIR" > /dev/null 2>&1
      
      # Common log function that all activation scripts can use
      log_nix() {
        local component="$1"
        local message="$2"
        local log_file="$NIX_LOG_DIR/$component.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
      }
      
      # Export the function so it's available to all activation scripts
      export -f log_nix
    '';

    # Packages to install to the user profile
    packages = with pkgs; [
      # System utilities
      coreutils
      findutils

      # Development languages and tools
      terraform
      dotnet-sdk
      buf
      subversion
      golangci-lint

      # Cloud tools
      kubectl
      kubectx
      k9s
      kubernetes-helm
      awscli2
      google-cloud-sdk

      # Search tools
      ripgrep

      # Git tools
      github-cli

      # Data processing tools
      yq

      # ZSH Enhancements
      zsh-powerlevel10k

      # GPG
      gnupg

      # Secrets management
      agenix
      vault
      _1password-cli
      _1password-gui

      # System utilities
      watch
      pre-commit
      nixpkgs-fmt
      statix


      # Tools
      obsidian
      code-cursor

      # Terminal

      # Communication
      slack

      # JetBrains IDEs
      jetbrains.rider
      jetbrains.goland
      jetbrains.pycharm-professional
      jetbrains.idea-ultimate
      jetbrains.datagrip

      # Misc
      direnv
    ];

    # This value determines the Home Manager release compatibility
    stateVersion = "24.11";
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
  };

  # Disable showing news on update
  news.display = "silent";

  # Tmux configuration
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1;
    terminal = "screen-256color";
    escapeTime = 0;
    historyLimit = 10000;

    mouse = true;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    aggressiveResize = true;
    clock24 = true;
    newSession = true;

    extraConfig = ''
      # Additional tmux configuration
      set -g status-style "bg=black,fg=white"

      # Synchronize panes
      bind-key sp set-window-option synchronize-panes\; display-message "synchronize-panes is now #{?pane_synchronized,on,off}"
    '';
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Configure rclone services in the correct dependency order
  services.rclone = {
    enable = true;
    configFile = ./modules/agenix/rclone.conf.age;
  };

  # Configure rclone mounting service with comprehensive configuration linking
  services.rclone-mount = {
    enable = true;
    mounts = [
      {
        remote = "aws-shavakan:shavakan-rclone";
        mountPoint = "${config.home.homeDirectory}/mnt/rclone";
        allowOther = false;
      }
    ];

    # Configure all files that should be linked from the mount directory
    linkedConfigurations = [
      {
        name = "kubeconfig";
        sourcePath = "kubeconfig";
        targetPath = "${config.home.homeDirectory}/.kube/config";
        permissions = "600";
        createTargetDir = true;
        backupExisting = true;
      }
      {
        name = "saml2aws";
        sourcePath = "saml2aws";
        targetPath = "${config.home.homeDirectory}/.saml2aws";
        permissions = "600";
        createTargetDir = true;
        backupExisting = true;
      }
      {
        name = "devsisters-script";
        sourcePath = "devsisters.sh";
        targetPath = "${config.home.homeDirectory}/.devsisters.sh";
        permissions = "755";
        createTargetDir = false;
        backupExisting = true;
      }
      {
        name = "claude-config";
        sourcePath = "claude/CLAUDE.md";
        targetPath = "${config.home.homeDirectory}/.claude/CLAUDE.md";
        permissions = "644";
        createTargetDir = true;
        backupExisting = true;
      }
      {
        name = "claude-settings";
        sourcePath = "claude/claude-settings.json";
        targetPath = "${config.home.homeDirectory}/.claude/settings.json";
        permissions = "644";
        createTargetDir = true;
        backupExisting = true;
      }
      {
        name = "claude-local-settings";
        sourcePath = "claude/claude-settings.local.json";
        targetPath = "${config.home.homeDirectory}/.claude/settings.local.json";
        permissions = "644";
        createTargetDir = true;
        backupExisting = true;
      }
    ];

    # Environment variables for linked configurations
    environmentVariables = {
      KUBECONFIG = "${config.home.homeDirectory}/.kube/config";
    };
  };

  # Enable cd-rclone for easier navigation to rclone mount directories
  programs.cd-rclone = {
    enable = true;
    extraDirs = {
      kube = "kubeconfigs";
    };
  };

  # Enable the rclone-launchd service last to avoid circular dependencies
  services.rclone-launchd = {
    enable = true;
  };

  themes.selected = "nord";

  # Mac App Store applications
  services.mas = {
    enable = true;
    appleId = "chiyah92@icloud.com";
    apps = {
      "Paste" = 967805235;
      "WireGuard" = 1451685025;
    };
  };

  # Enhanced GPG configuration
  programs.gpg = {
    enable = true;
    settings = {
      no-symkey-cache = true;
      use-agent = true;
      pinentry-mode = "loopback";
    };
  };

  # Configure GPG agent (without SSH support since we're using macOS SSH agent)
  services.gpg-agent = {
    enable = true;
    enableSshSupport = false;
    enableExtraSocket = true;
    defaultCacheTtl = 3600;
    maxCacheTtl = 86400;
    pinentry.package = pkgs.pinentry_mac;
    extraConfig = ''
      allow-loopback-pinentry
      allow-emacs-pinentry
      allow-preset-passphrase
    '';
  };

  # Enable awsctx service
  services.awsctx = {
    enable = true;
  };

  # Configure SSH with proper agent setup
  programs.ssh = {
    enable = true;

    matchBlocks = {
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
        user = "git";
      };
    };

    extraConfig = ''
      AddKeysToAgent yes
      IdentitiesOnly yes
    '';
  };
}
