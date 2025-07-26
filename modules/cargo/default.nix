{ config, lib, pkgs, fenix, ... }:

with lib;

let
  # Create a custom rust toolchain with the components we need
  rustToolchain = fenix.packages.${pkgs.system}.stable.withComponents [
    "cargo"
    "clippy"
    "rust-src"
    "rustc"
    "rustfmt"
    "rust-analyzer"
  ];
in
{
  # Add cargo configuration
  home.file.".cargo/config.toml" = {
    text = ''
      # Cargo configuration - managed by Nix

      [net]
      # Use system git CLI for fetching git dependencies
      # This helps with SSH authentication using macOS keychain and system ssh-agent
      git-fetch-with-cli = true
      
      # Enable unstable features
      [unstable]
      edition2024 = true
    '';
  };

  # Install Rust stable toolchain via fenix
  home.packages = [
    rustToolchain
  ];

  # Additional Cargo environment variables added to ZSH
  programs.zsh.envExtra = ''
    # Cargo SSH authentication helpers
    export CARGO_NET_GIT_FETCH_WITH_CLI=true
    
    # Ensure SSH agent socket is available for Git/Cargo
    # This allows cargo to use SSH for Git authentication
    if [ -z "$SSH_AUTH_SOCK" ]; then
      export SSH_AUTH_SOCK="$(launchctl getenv SSH_AUTH_SOCK)"
    fi
  '';
}
