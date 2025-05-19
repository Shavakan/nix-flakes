{ config, lib, pkgs, ... }:

with lib;

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

  # Install rustup and manage manually
  home.packages = with pkgs; [
    rustup
  ];
  
  # Additional Cargo environment variables added to ZSH
  programs.zsh.envExtra = ''
    # Cargo SSH authentication helpers
    export CARGO_NET_GIT_FETCH_WITH_CLI=true
    
    # Set nightly as the default toolchain
    export RUSTUP_TOOLCHAIN=nightly
    
    # Ensure SSH agent socket is available for Git/Cargo
    # This allows cargo to use SSH for Git authentication
    if [ -z "$SSH_AUTH_SOCK" ]; then
      export SSH_AUTH_SOCK="$(launchctl getenv SSH_AUTH_SOCK)"
    fi
  '';
  
  # Add activation script to install rust nightly if not already installed
  # This is more minimalistic than before
  home.activation.setupRustNightly = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ${pkgs.rustup}/bin/rustup toolchain list | grep -q nightly || \
    $DRY_RUN_CMD ${pkgs.rustup}/bin/rustup toolchain install nightly --profile minimal
  '';
}
