# Nix Flake Configuration

My personal Nix Flake configuration for managing consistent dotfiles across my machines.

## Features

- Home-manager configuration with nix-flakes
- Centralized theme management system
- Powerlevel10k ZSH configuration with consistent colors
- Dircolors integration for consistent file listings
- Git, Kubernetes, AWS, and other developer tool configurations

## Prerequisites

### 1. Install Nix

For macOS, run the official multi-user installation:
```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

**Note for macOS 15 Sequoia users:** If you encounter a "_nixbld1" user error, refer to [NixOS/nix#10892](https://github.com/NixOS/nix/issues/10892) for fixes.

See [official Nix installation guide](https://nixos.org/download) for other platforms.

### 2. Enable Flakes

Add to `~/.config/nix/nix.conf` (create if it doesn't exist):
```
experimental-features = nix-command flakes
```

### 3. Install Home Manager

Run the standalone installation:
```bash
nix run home-manager/master -- init --switch
```

This creates a basic configuration in `~/.config/home-manager`. See [Home Manager manual](https://nix-community.github.io/home-manager/) for details.

### 4. (Optional) Install nix-darwin for System Configuration

For macOS system-level settings:
```bash
sudo mkdir -p /etc/nix-darwin
cd /etc/nix-darwin
nix flake init -t nix-darwin/master
sudo nix run nix-darwin/master#darwin-rebuild -- switch
```

See [nix-darwin documentation](https://github.com/LnL7/nix-darwin) for full setup instructions.

## Setup

1. Clone this repository:
   ```bash
   git clone <your-repo-url> ~/nix-flakes
   cd ~/nix-flakes
   ```

2. **Always test before applying:**
   ```bash
   home-manager build --flake . --impure
   ```

3. Apply user configuration:
   ```bash
   make home
   ```

   **Note:** This runs in the background and can take 5-10 minutes.

4. (Optional) Apply system configuration:
   ```bash
   make darwin
   ```

## Usage

```bash
# Test changes without applying
home-manager build --flake . --impure

# Apply user configuration
make home

# Apply system configuration (macOS)
make darwin

# Update flake inputs
make update

# Clean up old generations
make clean
```

## Theme System

The configuration includes a centralized theme system that ensures consistent colors between:
- Terminal prompt (via Powerlevel10k)
- Directory listings (via LS_COLORS)
- Tab completion
- Git status

Available themes:
- `nord`: Nord theme with blue accent colors (default)
- `monokai`: Monokai theme with vibrant colors
- `solarized-dark`: Solarized Dark theme
- `solarized-light`: Solarized Light theme

To change themes, modify the `themes.selected` option in `home.nix`.

## Modules

- `themes`: Central theme management 
- `ls-colors`: Directory colors configuration
- `zsh`: ZSH shell with Powerlevel10k
- `git`: Git configuration
- `neovim`: Neovim text editor configuration
- And many more...
