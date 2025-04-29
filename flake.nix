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

    # ZSH plugins
    zsh-powerlevel10k = {
      url = "github:romkatv/powerlevel10k/v1.19.0";
      flake = false;
    };
    
    zsh-autopair = {
      url = "github:hlissner/zsh-autopair/34a8bca0c18fcf3ab1561caef9790abffc1d3d49";
      flake = false;
    };

    # Additional package sources (uncomment and modify as needed)
    # nur = {
    #   url = "github:nix-community/NUR";
    # };
  };

  outputs = { self, nixpkgs, darwin, home-manager, agenix, zsh-powerlevel10k, zsh-autopair, ... }@ inputs:
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
    # nix-darwin configuration for different machine types
    darwinConfigurations = {
      # MacBook configuration
      "MacBook-changwonlee" = darwin.lib.darwinSystem {
        system = darwinSystem;
        modules = [
          # Main darwin configuration
          ./modules/darwin/common.nix
          # MacBook-specific settings
          ./modules/darwin/macbook.nix
          # Set hostname explicitly
          { networking.hostName = "MacBook-changwonlee"; }
        ];
      };
      
      # Mac Studio configuration
      "macstudio-changwonlee" = darwin.lib.darwinSystem {
        system = darwinSystem;
        modules = [
          # Main darwin configuration
          ./modules/darwin/common.nix
          # Mac Studio-specific settings
          ./modules/darwin/macstudio.nix
          # Set hostname explicitly
          { networking.hostName = "macstudio-changwonlee"; }
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
        
        # Add hostname-aware modules
        ./modules/host-config
      ];
      
      # Extra special args to pass to home.nix
      extraSpecialArgs = {
        inherit username agenix zsh-powerlevel10k zsh-autopair;
      };
    };
    
    # Development shells for the project
    devShells.${darwinSystem}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        nixpkgs-fmt
        nixfmt
        statix   # Lints and suggestions for Nix code
        nix-linter
      ];
    };
  };
}
