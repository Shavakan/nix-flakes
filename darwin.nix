{ pkgs, ... }:

{
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
    google-chrome
    
    # Container tools
    podman
  ];

  # Ensure binaries are linked properly
  environment.pathsToLink = [ "/bin" ];

  # Replace system vim with neovim as editor 
  environment.variables = {
    EDITOR = "nvim";
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
        "wvous-bl-corner" = 1;  # Bottom left: Disabled
        "wvous-br-corner" = 1;  # Bottom right: Disabled
      };
    };
  };

  # System state version
  system.stateVersion = 5;
}
