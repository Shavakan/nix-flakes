{ config, pkgs, lib, ... }:

{
  # Import the main VS Code configuration
  imports = [ ./default.nix ];

  # macOS-specific VS Code configuration
  programs.vscode = {
    # For macOS, we need to enable Home Manager to properly install GUI applications
    # and make them appear in Spotlight/Finder

    # Use the specific package for macOS - this ensures that the application appears in Launchpad
    package = pkgs.vscode;

    # Ensure the application directory exists
    enable = true;

    # These settings work in conjunction with the mac-app-util in flake.nix
    # without modifying what's already configured in default.nix
  };

  # Add activation scripts to ensure VSCode is properly installed and linked
  home.activation = {
    # Information notification
    vscodeNotification = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD echo "VS Code will be installed with Home Manager"
      $DRY_RUN_CMD echo "Extensions and configuration are managed by Nix"
      $DRY_RUN_CMD echo "To see installed extensions, use: code --list-extensions"
    '';

    # Ensure VSCode is properly linked in Applications
    linkVSCodeApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Find the VSCode.app path in the Nix store
      VSCODE_APP_PATH=$(find "$HOME/.nix-profile" -name "Visual Studio Code.app" -type d 2>/dev/null || echo "")
      
      # If found, ensure it's properly linked to Applications
      if [ -n "$VSCODE_APP_PATH" ]; then
        if [ ! -e "/Applications/Visual Studio Code.app" ] || [ -L "/Applications/Visual Studio Code.app" ]; then
          $DRY_RUN_CMD ln -sfn "$VSCODE_APP_PATH" "/Applications/Visual Studio Code.app"
          echo "Linked Visual Studio Code.app to Applications folder"
        fi
      else
        echo "Warning: Could not find Visual Studio Code.app in nix profile"
      fi
    '';
  };
}
