# Nix Flake Configuration

My personal Nix Flake configuration for managing consistent dotfiles across my machines.

## Features

- Home-manager configuration with nix-flakes
- Centralized theme management system
- Powerlevel10k ZSH configuration with consistent colors
- Dircolors integration for consistent file listings
- Git, Kubernetes, AWS, and other developer tool configurations

## Usage

```bash
# Install new changes
home-manager switch --flake . --impure

# Test changes without applying
home-manager build --flake . --impure

# Check current theme
show_current_theme
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
