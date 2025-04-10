{
  description = "Nix flake with nix-darwin and standalone home-manager";

  inputs = {
    # Package sources
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    # nix-darwin
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # home-manager, as a standalone component
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, darwin, home-manager }:
  let
    # Current system (assuming ARM macOS, change if needed)
    darwinSystem = "aarch64-darwin";
    
    # Import nixpkgs
    pkgs = import nixpkgs {
      system = darwinSystem;
      config.allowUnfree = true;
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
            
            # Add a helpful message about home-manager
            system.activationScripts.postActivation.text = ''
              echo "nix-darwin successfully activated!"
              echo "To activate home-manager, run: 'home-manager switch --flake .'"
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
      
      # Pass arguments to home.nix
      extraSpecialArgs = {
        inherit username;
      };
    };
  };
}
