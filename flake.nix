{
  description = "Nix flake with nix-darwin and standalone home-manager";

  inputs = {
    # Package sources - use nixpkgs-unstable for latest packages
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixpkgs-master for bleeding-edge packages (claude-code)
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    # Custom saml2aws build from devsisters fork
    saml2aws = {
      url = "github:devsisters/saml2aws";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Fenix for Rust toolchain management
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-vscode-extensions - for VS Code extensions from marketplace
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # Vim plugins
    vim-nord = {
      url = "github:arcticicestudio/nord-vim";
      flake = false;
    };

    vim-surround = {
      url = "github:tpope/vim-surround";
      flake = false;
    };

    vim-commentary = {
      url = "github:tpope/vim-commentary";
      flake = false;
    };

    vim-easy-align = {
      url = "github:junegunn/vim-easy-align";
      flake = false;
    };

    fzf-vim = {
      url = "github:junegunn/fzf.vim";
      flake = false;
    };

    vim-fugitive = {
      url = "github:tpope/vim-fugitive";
      flake = false;
    };

    vim-nix = {
      url = "github:LnL7/vim-nix";
      flake = false;
    };

    vim-terraform = {
      url = "github:hashivim/vim-terraform";
      flake = false;
    };

    vim-go = {
      url = "github:fatih/vim-go";
      flake = false;
    };

    # kubectl-snack - Kubernetes node pricing visualization
    kubectl-snack = {
      url = "git+ssh://git@github.com/devsisters/kubectl-snack.git";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-master, darwin, home-manager, agenix, zsh-powerlevel10k, zsh-autopair, vim-nord, vim-surround, vim-commentary, vim-easy-align, fzf-vim, vim-fugitive, vim-nix, vim-terraform, vim-go, nix-vscode-extensions, saml2aws, fenix, kubectl-snack, ... }@ inputs:
    let
      # Current system (assuming ARM macOS, change if needed)
      darwinSystem = "aarch64-darwin";

      # Import nixpkgs-master with unfree allowed
      pkgs-master = import nixpkgs-master {
        system = darwinSystem;
        config.allowUnfree = true;
      };

      # Common overlays used across all configurations
      commonOverlays = [
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
        # Add custom saml2aws
        (final: prev: {
          saml2aws = saml2aws.packages.${darwinSystem}.default;
        })
        # Override claude-code with master version
        (final: prev: {
          claude-code = pkgs-master.claude-code;
        })
        # Add nix-vscode-extensions overlay
        nix-vscode-extensions.overlays.default
        # Add kubectl-snack
        (final: prev: {
          kubectl-snack = final.buildGoModule {
            pname = "kubectl-snack";
            version = "0.1.0";
            src = kubectl-snack;
            vendorHash = "sha256-yNwGJM/dyYlVJSwl408ACcNt8jC1HYbysCNyPpYctxU=";
            subPackages = [ "cmd/kubectl-snack" ];
            meta = {
              description = "kubectl plugin to display Kubernetes node info with AWS pricing";
              mainProgram = "kubectl-snack";
            };
          };
        })
      ];

      # Import nixpkgs
      pkgs = import nixpkgs {
        system = darwinSystem;
        config.allowUnfree = true;
        overlays = commonOverlays;
      };

      # Username
      username = "shavakan";
    in
    {
      # nix-darwin configuration for different machine types
      darwinConfigurations = {
        # MacBook configuration
        "MacBook-changwonlee" = darwin.lib.darwinSystem {
          system = darwinSystem;
          modules = [
            # Configure nixpkgs with overlays
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = commonOverlays;
            }
            # Main darwin configuration
            ./modules/darwin
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
            # Configure nixpkgs with overlays
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = commonOverlays;
            }
            # Main darwin configuration
            ./modules/darwin
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

          ./modules/host-config

          {
            imports = [
              ./modules/mas
            ];
          }
        ];

        # Extra special args to pass to home.nix
        extraSpecialArgs = {
          inherit username agenix zsh-powerlevel10k zsh-autopair;
          # Pass vim plugins
          inherit vim-nord vim-surround vim-commentary vim-easy-align fzf-vim vim-fugitive vim-nix vim-terraform vim-go;
          # Add nix-vscode-extensions for VS Code
          inherit nix-vscode-extensions;
          # Add custom inputs
          inherit saml2aws fenix;
        };
      };

      # Development shells for the project
      devShells.${darwinSystem} = {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Single formatter
            nixpkgs-fmt # Standard Nix formatter

            # Single linter
            statix # Comprehensive linter for Nix code

            # Pre-commit framework
            pre-commit # Git hook manager
          ];

          # Add SSH agent forwarding for all shells
          shellHook = ''
            # Ensure SSH agent is available
            if [ -z "$SSH_AUTH_SOCK" ]; then
              export SSH_AUTH_SOCK="$(launchctl getenv SSH_AUTH_SOCK)"
            fi
            
            # Configure cargo to use the system Git client
            export CARGO_NET_GIT_FETCH_WITH_CLI=true
            
            echo "SSH_AUTH_SOCK is set to: $SSH_AUTH_SOCK"
            echo "Development environment ready!"
          '';
        };

        # Rust development shell with nightly toolchain from fenix
        rust = pkgs.mkShell {
          # Environment variables for the shell
          CARGO_NET_GIT_FETCH_WITH_CLI = "true";

          # Use fenix for the Rust toolchain
          packages = [
            # Use stable toolchain instead of latest due to build issues
            (fenix.packages.${pkgs.stdenv.hostPlatform.system}.stable.withComponents [
              "cargo"
              "clippy"
              "rust-src"
              "rustc"
              "rustfmt"
              "rust-analyzer"
            ])

            # Development dependencies
            pkgs.pkg-config
            pkgs.openssl.dev
          ];

          shellHook = ''
            # Ensure SSH agent is available
            if [ -z "$SSH_AUTH_SOCK" ]; then
              export SSH_AUTH_SOCK="$(launchctl getenv SSH_AUTH_SOCK)"
            fi
            
            echo "Rust nightly development shell ready!"
          '';
        };
      };
    };
}
