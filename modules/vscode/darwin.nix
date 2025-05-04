{ config, pkgs, lib, ... }:

{
  # Import the main VS Code configuration
  imports = [ ./default.nix ];

  # macOS-specific VS Code configuration
  programs.vscode = {
    # For macOS, we need to enable Home Manager to properly install GUI applications
    # and make them appear in Spotlight/Finder
    
    # On macOS, VS Code is typically installed via Spotlight
    # When using home-manager on macOS, we need to ensure it's properly linked
    # using mac-app-util for proper integration with Spotlight
    
    # These settings work in conjunction with the mac-app-util in flake.nix
    # without modifying what's already configured in default.nix
  };

  # Add a note to the Home Manager activation
  home.activation.vscodeNotification = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD echo "VS Code will be installed with Home Manager"
    $DRY_RUN_CMD echo "Extensions and configuration are managed by Nix"
    $DRY_RUN_CMD echo "To see installed extensions, use: code --list-extensions"
  '';
}
