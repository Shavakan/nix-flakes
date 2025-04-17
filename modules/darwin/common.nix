# Common darwin configurations for all machines
[
  # Import the main darwin.nix file
  ../../darwin.nix

  # Common darwin settings
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
  }
]
