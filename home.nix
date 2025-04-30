{ config, pkgs, lib, hostname, zsh-powerlevel10k, zsh-autopair, vim-nord, vim-surround, vim-commentary, vim-easy-align, fzf-vim, vim-fugitive, vim-nix, vim-terraform, vim-go, ... }@args:

{
  # Import configurations
  imports = [
    # ./mcp-servers.nix
    ./modules/rclone
    ./modules/awsctx
    ./modules/git
    ./modules/neovim
    ./modules/zsh
    ./modules/claude
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

  # Configure rclone mounting service with integrated kubeconfig support
  services.rclone-mount = {
    enable = true;
    mounts = [
      {
        remote = "aws-shavakan:shavakan-rclone";
        mountPoint = "${config.home.homeDirectory}/mnt/rclone";
        allowOther = false;
      }
    ];

    # Kubeconfig path within rclone mount
    kubeConfigPath = "kubeconfig";
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

  # Enable awsctx service with zsh support
  services.awsctx = {
    enable = true;
    includeZshSupport = true;
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

  # Create an activation script that loads the Devsisters script after mount
  home.activation.loadAndSourceDevsistersScript = lib.hm.dag.entryAfter [ "mountRcloneRemotes" ] ''
    SCRIPT_PATH="$HOME/mnt/rclone/devsisters.sh"
    LINK_PATH="$HOME/.devsisters.sh"
    
    # Check if mount is available and script exists
    if [ -f "$SCRIPT_PATH" ]; then
      # Update symlink if needed
      $DRY_RUN_CMD ln -sf "$SCRIPT_PATH" "$LINK_PATH"
      
      # Try to source it immediately for this session
      if [ -f "$LINK_PATH" ]; then
        # Create a temporary wrapper script that sources the Devsisters script
        TEMP_SCRIPT=$(mktemp)
        echo "#!/bin/bash" > "$TEMP_SCRIPT"
        echo "source \"$LINK_PATH\"" >> "$TEMP_SCRIPT"
        chmod +x "$TEMP_SCRIPT"
        
        # Execute the temporary script
        $DRY_RUN_CMD "$TEMP_SCRIPT" > /dev/null 2>&1 || true
        rm -f "$TEMP_SCRIPT"
      fi
    fi
  '';
}
