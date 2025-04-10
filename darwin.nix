{ pkgs, ... }:

{
  # Allow unfree packages (for vscode, slack, chrome, etc.)
  nixpkgs.config.allowUnfree = true;

  # System packages available to all users - combined all packages here
  environment.systemPackages = with pkgs; [
    # Core system utilities
    neovim
    coreutils
    curl
    wget
    gnupg
    openssh
    
    # Applications (GUI)
    podman
    iterm2
    vscode
    slack
    google-chrome
    
    # Database and system services (these run globally)
    redis
  ];

  # Replace system vim with neovim as editor 
  environment.variables.EDITOR = "nvim";
  
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

  # Configure keyboard
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  # Enable related services
  programs.nix-index.enable = true;

  # Shell configuration
  programs.zsh.enable = true;
  programs.bash.enable = true;
  
  # Extra settings for Nix
  nix.package = pkgs.nix;

  system.defaults = {
    # Dock settings
    dock = {
      autohide = true;
      orientation = "bottom";
      showhidden = true;
      mineffect = "scale";
    };
    
    # Finder settings
    finder = {
      AppleShowAllExtensions = true;
      QuitMenuItem = true;
      FXEnableExtensionChangeWarning = false;
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
    };
  };

  system.stateVersion = 4;
}
