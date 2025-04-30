# modules/darwin/default.nix (previously common.nix)
{ pkgs, ... }:

{
  # Import all services
  imports = [
    ./services
  ];

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
    
    # Add skhd explicitly to ensure it's available 
    skhd
  ];

  # Enable Homebrew management through nix-darwin
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true; # Auto-update Homebrew on activation
      cleanup = "zap"; # Uninstall packages not in the spec
      upgrade = true; # Upgrade outdated packages
    };
    casks = [
      "macfuse" # Install macFUSE as a cask
      "notion" # Install Notion
    ];
    global = {
      brewfile = true; # Use Brewfile for manual operations too
      autoUpdate = false; # Disable auto-updates for manual operations
    };
  };

  # Ensure binaries are linked properly
  environment.pathsToLink = [ "/bin" ];

  # System environment variables
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
      _FXShowPosixPathInTitle = true; # Show full POSIX path in Finder window title
      _FXSortFoldersFirst = true; # Keep folders on top when sorting by name
      FXPreferredViewStyle = "clmv"; # Use column view by default (other options: "icnv", "Nlsv", "glyv")
      CreateDesktop = true; # Show desktop icons
      ShowExternalHardDrivesOnDesktop = true; # Show external drives on desktop
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

    # Stage Manager configuration - new window management feature in macOS Ventura+
    WindowManager = {
      GloballyEnabled = true; # Enable Stage Manager by default
      AppWindowGroupingBehavior = true; # Group windows by application
      AutoHide = true; # Auto hide recent apps strip
      HideDesktop = false; # Don't hide desktop items
      StageManagerHideWidgets = false; # Don't hide widgets
      # Enable window tiling via edge dragging
      EnableTilingByEdgeDrag = true;
      # Allow the hotkey toggle to work properly by monitoring for changes
      EnableStandardClickToShowDesktop = true;
    };

    # Trackpad 
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
    };

    # Security settings
    screencapture.location = "/Users/shavakan/Desktop";

    # Control Center settings
    controlcenter = {
      BatteryShowPercentage = true; # Show battery percentage
    };

    # Login window and security settings
    loginwindow = {
      # Require password immediately after sleep or screen saver begins
      GuestEnabled = false; # Disable guest account
      DisableConsoleAccess = true; # Disable console access
    };

    # Security settings
    CustomUserPreferences = {
      # Hot corners
      "com.apple.dock" = {
        "wvous-tl-corner" = 1; # Top left: Disabled
        "wvous-tr-corner" = 1; # Top right: Disabled  
        "wvous-bl-corner" = 13; # Bottom left: Lock Screen
        "wvous-br-corner" = 1; # Bottom right: Disabled
      };

      # Security settings
      "com.apple.screensaver" = {
        "idleTime" = 300; # Start screen saver after 5 minutes (300 seconds)
        "askForPassword" = 1; # Require password when screen is locked
        "askForPasswordDelay" = 0; # Require password immediately (no delay)
      };

      # iCloud services configuration
      "com.apple.iCloud" = {
        # iCloud Drive
        "DVAdHocSharing" = true; # Allow iCloud Drive document sharing
        "APImportantDocuments" = true; # Allow Desktop and Documents syncing
        "DocumentManagerEnabled" = true; # Enable Document manager

        # Find My Mac
        "com.apple.iCloud.sync.daemon.enableFindMyMac" = true;

        # iCloud Keychain
        "KeychainSyncEnabled" = true;

        # iCloud Backup
        "MobileDocumentsBackupsEnabled" = true;

        # Photo Library
        "PhotosAutoImport" = true;
        "PhotosEnabled" = true;
      };

      # Apple Media Services
      "com.apple.AppleMediaServices" = {
        # Apple Music
        "AMSSubscriptionStatusShowSubscribedContent" = true;

        # App Store
        "AMSUserInterface_ShowSubscribedContent" = true;
      };

      # Apple TV
      "com.apple.tv" = {
        "WatchlistEnabled" = true;
      };

      # Apple Pay and Wallet
      "com.apple.PassKit" = {
        # Apple Pay
        "ApplePayEnabled" = true;
        "ApplePayPreferred" = true;
      };

      # iMessage and FaceTime
      "com.apple.iMessage" = {
        "MessageSyncEnabled" = true;
        "SMSRelayEnabled" = true;
      };

      "com.apple.FaceTime" = {
        "FaceTimeRecentMax" = 30; # Number of recent calls to store
      };

      # iWork Suite
      "com.apple.iWork.Pages" = {
        "IWAutomaticallySyncToiCloud" = true;
      };

      "com.apple.iWork.Numbers" = {
        "IWAutomaticallySyncToiCloud" = true;
      };

      "com.apple.iWork.Keynote" = {
        "IWAutomaticallySyncToiCloud" = true;
      };

      # Other Apple Services
      "com.apple.Photos" = {
        "IPXPCPhotosMigrationEnabled" = true;
        "IPXPhotosCloudSharingEnabled" = true;
      };

      "com.apple.reminders" = {
        "EnableCloudKitSync" = true;
      };

      # Additional security settings
      "com.apple.screensaver.loginscreen" = {
        "askForPassword" = 1; # Always require password
        "askForPasswordDelay" = 0; # No delay before requiring password
      };

      # System preferences security settings
      "com.apple.systempreferences" = {
        "RequirePasswordBoot" = true; # Require password at boot
        "RequirePasswordUnlock" = true; # Require password to unlock
      };

      # Apple Watch unlock settings
      "com.apple.autounlock" = {
        "enabled" = 1; # Enable Apple Watch Auto Unlock
        "disable-proximity-notifications" = 0; # Allow proximity notifications
      };

      # Security & Privacy preferences
      "com.apple.security" = {
        "AutoWake" = true; # Wake for network access
        "DisableLockOnSleep" = false; # Lock when sleeping
        "UseProximityMonitoring" = true; # Use Apple Watch for proximity monitoring
      };

      # Firewall settings
      "com.apple.alf" = {
        "globalstate" = 1; # Enable firewall
        "allowsignedenabled" = 1; # Allow signed apps
        "stealthenabled" = 1; # Enable stealth mode (don't respond to ICMP ping requests)
        "loggingenabled" = 0; # Disable firewall logging
      };

      # Control Center Menu Items - since these aren't directly available in controlcenter settings
      "com.apple.controlcenter" = {
        "WiFi" = 18; # Show WiFi in Control Center and menu bar 
        "Bluetooth" = 18; # Show Bluetooth in Control Center and menu bar
        "Sound" = 8; # Show in Control Center only
        "NowPlaying" = 8; # Show in Control Center only
        "FocusModes" = 18; # Show in Control Center and menu bar
        "AirDrop" = 8; # Show in Control Center only
      };
    };
  };

  # System state version
  system.stateVersion = 5;
}
