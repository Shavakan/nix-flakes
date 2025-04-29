{ pkgs, ... }:

{
  # Enable nix
  nix.enable = true;
  
  # Fix for nixbld group ID mismatch
  ids.gids.nixbld = 350;
  
  # Add a helpful message about home-manager
  system.activationScripts.postActivation.text = ''
    echo "nix-darwin successfully activated!"
    echo "To activate home-manager, run: 'LANG=en_US.UTF-8 home-manager switch --flake . --impure'"
  '';
  
  # Allow unfree packages for vscode, etc.
  nixpkgs.config.allowUnfree = true;

  # System packages available to all users
  environment.systemPackages = with pkgs; [
    # Development tools
    git
    neovim
    python3
    nodejs
    go
    rustup
    cargo

    # Package managers
    uv

    # System-level tools
    coreutils
    openssh
    curl
    wget
    ripgrep
    jq

    # CLI utilities
    tmux
    htop
    bat
    mtr
    ripgrep
    fd
    jq
    fzf
    tree
    
    # GUI applications
    vscode
    slack
    iterm2
    alacritty
    google-chrome
    
    # Container tools
    podman
    podman-compose
  ];
  
  # Enable Homebrew management through nix-darwin
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;  # Auto-update Homebrew on activation
      cleanup = "zap";   # Uninstall packages not in the spec
      upgrade = true;    # Upgrade outdated packages
    };
    casks = [
      "macfuse"  # Install macFUSE as a cask
    ];
  };

  # Ensure binaries are linked properly
  environment.pathsToLink = [ "/bin" ];

  # System environment variables
  environment.variables = {
    EDITOR = "nvim";
  };
  
  # LaunchAgents to set environment variables for GUI applications
  launchd.user.agents = {
    set-env = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "launchctl setenv CLAUDE_MCP_CONFIG /Users/shavakan/.claude-mcp-config.json"
        ];
        RunAtLoad = true;
        KeepAlive = false;
      };
    };
  };
  
  # Enable nix-command and flakes support
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # Do NOT remap Caps Lock to Escape - we want to use it for language switching
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = false;
  };

  # Enable related services
  programs.nix-index.enable = true;

  # Shell configuration
  programs.zsh.enable = true;
  programs.bash.enable = true;

  # Extra settings for Nix
  nix.package = pkgs.nix;

  # System defaults for macOS
  system.defaults = {
    # Dock settings
    dock = {
      autohide = true;
      orientation = "bottom";
      showhidden = true;
      mineffect = "scale";
      mru-spaces = false;
      show-recents = false;
    };
    
    # Finder settings
    finder = {
      AppleShowAllExtensions = true;
      QuitMenuItem = true;
      FXEnableExtensionChangeWarning = false;
      ShowPathbar = true;
      ShowStatusBar = true;
    };
    
    # General settings
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      AppleKeyboardUIMode = 3;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      _HIHideMenuBar = false;
      
      # Key repeat
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };
    
    # Trackpad 
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
    };
    
    # Hot corners
    CustomUserPreferences = {
      # Hot corners
      "com.apple.dock" = {
        "wvous-tl-corner" = 1;  # Top left: Disabled
        "wvous-tr-corner" = 1;  # Top right: Disabled  
        "wvous-bl-corner" = 10; # Bottom left: Put display to sleep
        "wvous-br-corner" = 1;  # Bottom right: Disabled
      };

      # Screen saver settings
      "com.apple.screensaver" = {
        "idleTime" = 300;       # Start screen saver after 5 minutes (300 seconds)
      };
    };
  };

  # System state version
  system.stateVersion = 5;
}
