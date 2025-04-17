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
    
    # agenix for secrets management
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Additional package sources (uncomment and modify as needed)
    # nur = {
    #   url = "github:nix-community/NUR";
    # };
  };

  outputs = { self, nixpkgs, darwin, home-manager, agenix, ... }@ inputs:
  let
    # Current system (assuming ARM macOS, change if needed)
    darwinSystem = "aarch64-darwin";
    
    # Import nixpkgs
    pkgs = import nixpkgs {
      system = darwinSystem;
      config.allowUnfree = true;
      # Add overlays
      overlays = [
        # Add unstable channel
        (final: prev: {
          unstable = import nixpkgs {
            system = darwinSystem;
            config.allowUnfree = true;
          };
        })
        # Add agenix to pkgs
        (final: prev: {
          agenix = agenix.packages.${darwinSystem}.default;
        })
      ];
    };
    
    # Username
    username = "shavakan";
  in {
    # nix-darwin configuration
    darwinConfigurations = {
      # Configuration for MacBook
      "MacBook-changwonlee" = darwin.lib.darwinSystem {
        system = darwinSystem;
        modules = [
          # Main darwin configuration
          ./darwin.nix
          # Machine-specific settings
          ./modules/darwin/macbook.nix
        ];
      };
      
      # Configuration for Mac Studio (new machine)
      "macstudio-changwonlee" = darwin.lib.darwinSystem {
        system = darwinSystem;
        modules = [
          # Main darwin configuration
          ./darwin.nix
          # Machine-specific settings
          ./modules/darwin/macstudio.nix
        ];
      };
      
      # Default to MacBook configuration
      default = self.darwinConfigurations."MacBook-changwonlee";
    };
    
    # Standalone home-manager configuration
    homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      
      # Specify your home configuration modules
      modules = [
        ./home.nix
        agenix.homeManagerModules.default
      ];
      
      # Extra special args to pass to home.nix
      extraSpecialArgs = {
        inherit username agenix;
      };
    };
  };
}
