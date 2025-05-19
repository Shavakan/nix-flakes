# Cargo Module for Home Manager

This module configures Rust and Cargo to use:

1. **Rustup with Nightly Toolchain** - Uses rustup to manage Rust toolchains
2. **Git Auth Support** - Uses the system git client for SSH authentication
3. **Edition2024 Support** - Enables unstable features needed for some packages

## Features

- Uses rustup with a minimalistic approach to manage toolchains
- Configures `.cargo/config.toml` for consistent settings
- Sets up SSH agent forwarding for Git authentication
- Sets environment variables for nightly and Git authentication
- Installs nightly toolchain only if not already installed

## How It Works

This module takes a minimalist approach to Rust toolchain management using rustup:

1. Installs rustup through Nix
2. Sets up environment variables to use nightly by default
3. Provides an activation script that only installs nightly if needed
4. Configures Git authentication for cargo dependencies

### Manual Installation

If you need to set up the environment before Home Manager runs:

```bash
# Install rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install nightly and set as default
rustup toolchain install nightly
rustup default nightly

# Set Git to use SSH authentication
mkdir -p ~/.cargo
echo '[net]
git-fetch-with-cli = true

[unstable]
edition2024 = true' > ~/.cargo/config.toml

# For the current session
export RUSTUP_TOOLCHAIN=nightly
export CARGO_NET_GIT_FETCH_WITH_CLI=true
```

## Usage with Nix Development Shells

To enter a Rust nightly development shell:

```bash
nix develop .#rust
```
