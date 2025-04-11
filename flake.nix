{
  description = "Nix flake with nix-darwin and standalone home-manager";

  inputs = {
    # Package sources - use nixpkgs-unstable for compatibility
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    # nix-darwin - use master for unstable
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # home-manager - use master to match nixpkgs-unstable
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Additional package sources (uncomment and modify as needed)
    # nur = {
    #   url = "github:nix-community/NUR";
    # };
  };

  outputs = { self, nixpkgs, darwin, home-manager, ... }@ inputs:
  let
    # Current system (assuming ARM macOS, change if needed)
    darwinSystem = "aarch64-darwin";
    
    # Import nixpkgs
    pkgs = import nixpkgs {
      system = darwinSystem;
      config.allowUnfree = true;
      # Add unstable channel
      overlays = [
        (final: prev: {
          unstable = import nixpkgs {
            system = darwinSystem;
            config.allowUnfree = true;
          };
        })
      ];
    };
    
    # Username
    username = "shavakan";
  in {
    # nix-darwin configuration
    darwinConfigurations = {
      # Configuration for your hostname
      "MacBook-changwonlee" = darwin.lib.darwinSystem {
        system = darwinSystem;
        
        modules = [
          # Import your darwin.nix file
          ./darwin.nix
          
          # Basic system configuration
          {
            # Enable nix
            nix.enable = true;
            
            # Set a system hostname
            networking.hostName = "MacBook-changwonlee";
            
            # Fix for nixbld group ID mismatch
            ids.gids.nixbld = 350;
            
            # Allow unfree packages
            nixpkgs.config.allowUnfree = true;
            
            # Configure keyboard for language switching with Caps Lock
            system.keyboard = {
              enableKeyMapping = true;
              remapCapsLockToControl = false;
              remapCapsLockToEscape = false;
              # Don't remap Caps Lock in nix-darwin
            };
            
            # Add a helpful message about home-manager
            system.activationScripts.postActivation.text = ''
              echo "nix-darwin successfully activated!"
              echo "To activate home-manager, run: 'LANG=en_US.UTF-8 home-manager switch --flake .'"
            '';
          }
        ];
      };
      
      # Keep default configuration as an alias
      default = self.darwinConfigurations."MacBook-changwonlee";
    };
    
    # Standalone home-manager configuration
    homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      
      # Specify your home configuration modules
      modules = [ ./home.nix ];
      
      # Extra special args to pass to home.nix
      extraSpecialArgs = {
        inherit username;
      };
    };
  };
}
