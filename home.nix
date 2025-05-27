{ config, pkgs, lib, hostname, zsh-powerlevel10k, zsh-autopair, vim-nord, vim-surround, vim-commentary, vim-easy-align, fzf-vim, vim-fugitive, vim-nix, vim-terraform, vim-go, ... }@args:

{
  # Import configurations
  imports = [
    # ./mcp-servers.nix
    # Load themes first, then ls-colors, then other modules
    ./modules/themes # Centralized theme management
    ./modules/ls-colors # Add colorized ls support
    ./modules/rclone
    ./modules/awsctx
    ./modules/git
    ./modules/neovim
    ./modules/zsh
    ./modules/claude
    ./modules/vscode
    ./modules/cargo # Cargo configuration with SSH agent support for Git dependencies
    ./modules/iterm2 # iTerm2 configuration (migrated from nix-darwin)
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
      # System utilities
      coreutils # GNU coreutils for ls with color support
      findutils # GNU find, locate, and xargs

      # Development languages and tools
      terraform
      dotnet-sdk # .NET SDK (current version)

      # Cloud tools
      kubectl
      kubectx
      k9s
      kubernetes-helm # Explicitly use kubernetes-helm, not the audio synthesizer
      awscli2
      saml2aws
      google-cloud-sdk

      # Search tools
      ripgrep # Fast search tool (used in place of the missing oh-my-zsh plugin)

      # ZSH Enhancements
      zsh-powerlevel10k # Powerlevel10k theme (installed directly)

      # GPG
      gnupg

      # Secrets management
      agenix
      vault

      # System utilities
      watch
      pre-commit # Pre-commit hook framework
      nixpkgs-fmt # Nix formatter
      statix # Nix linter

      # Tools
      obsidian

      # Terminal
      # iterm2 is now managed by the programs.iterm2 module

      # Communication
      slack # Slack desktop client

      # JetBrains IDEs
      jetbrains.rider # .NET IDE
      jetbrains.goland # Go IDE
      jetbrains.pycharm-professional # Python IDE
      jetbrains.idea-ultimate # Java/Kotlin IDE
      jetbrains.datagrip # Database IDE

      # Misc
      direnv
    ];

    # This value determines the Home Manager release compatibility
    stateVersion = "24.11";
  };

  # Allow unfree packages (required for JetBrains IDEs)
  nixpkgs.config.allowUnfree = true;

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
      # GPG config is now managed by home-manager, not through rclone mount
      # Add more configurations as needed
      # {
      #   name = "aws-config";
      #   sourcePath = "aws/config";
      #   targetPath = "${config.home.homeDirectory}/.aws/config";
      #   permissions = "600";
      #   createTargetDir = true;
      #   backupExisting = true;
      # }
    ];

    # Environment variables for linked configurations
    environmentVariables = {
      KUBECONFIG = "${config.home.homeDirectory}/.kube/config";
      # Add other environment variables as needed
    };
  };

  # Enable cd-rclone for easier navigation to rclone mount directories
  programs.cd-rclone = {
    enable = true;
    extraDirs = {
      kube = "kubeconfigs";
      # Add more shortcuts as needed for other directories
    };
  };

  # Enable the rclone-launchd service last to avoid circular dependencies
  services.rclone-launchd = {
    enable = true;
  };

  # Configure themes for terminal and related utilities
  themes.selected = "nord"; # Options: nord, monokai, solarized-dark, solarized-light

  # Enhanced GPG configuration
  programs.gpg = {
    enable = true;
    settings = {
      # Enable more compatibility options
      no-symkey-cache = true;
      # Use agent and pinentry loopback modes
      use-agent = true;
      pinentry-mode = "loopback";
    };
  };

  # Configure GPG agent (without SSH support since we're using macOS SSH agent)
  services.gpg-agent = {
    enable = true;
    enableSshSupport = false; # Disable SSH support to avoid conflicts with macOS SSH agent
    enableExtraSocket = true;
    # Increased cache timeout to avoid frequent prompts
    defaultCacheTtl = 3600;
    maxCacheTtl = 86400;
    # Use pinentry for passphrase prompting
    pinentryPackage = pkgs.pinentry_mac;
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

    # Add your existing SSH config
    matchBlocks = {
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
        user = "git";
      };
    };

    # Use proper SSH agent settings tailored for macOS
    extraConfig = ''
      # Use SSH agent for authentication and macOS keychain integration
      AddKeysToAgent yes
      # UseKeychain yes
      
      # Add identities with confirmation
      IdentitiesOnly yes
    '';
  };
}
