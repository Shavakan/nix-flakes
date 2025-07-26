# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

```bash
# Apply home-manager configuration changes
home-manager switch --flake . --impure
make home  # equivalent shortcut

# Build without applying (test changes)
home-manager build --flake . --impure

# Apply darwin (system-level) configuration
darwin-rebuild switch --flake .#$(hostname) --impure
make darwin  # equivalent shortcut

# Update flake inputs
nix flake update
make update  # equivalent shortcut

# Clean up old generations and optimize store
nix-collect-garbage -d
nix-store --optimise
make clean  # equivalent shortcut

# Format Nix code
nixpkgs-fmt **/*.nix

# Lint Nix code
statix check

# Enter development shell with formatting/linting tools
nix develop

# Enter Rust development shell with fenix toolchain
nix develop .#rust

# Check current theme
show_current_theme
```

## Architecture Overview

This repository uses a dual configuration approach combining nix-darwin for system-level macOS settings and home-manager for user-specific configurations. The flake structure supports multiple machine types (MacBook, Mac Studio) with shared and machine-specific modules.

### Key Configuration Files
- `flake.nix`: Main flake definition with inputs, outputs, and system configurations
- `home.nix`: Home Manager entry point importing all user modules
- `Makefile`: Convenient shortcuts for common operations

### Module Organization

**Core Structure:**
- `modules/darwin/`: System-level macOS configurations (dock, finder, security, fonts)
- `modules/themes/`: Centralized theme management system supporting multiple themes
- `modules/*/`: Individual feature modules (git, zsh, neovim, vscode, etc.)

**Module Patterns:**
- Standard options/config pattern with `mkEnableOption` and `mkIf cfg.enable`
- Multi-file modules split functionality across specialized files
- Heavy use of activation scripts for runtime configuration
- Cross-module theme injection via `_module.args.selectedTheme`

### Theme System
The centralized theme system (`modules/themes/`) provides consistent colors across:
- Terminal prompt (Powerlevel10k)
- Directory listings (LS_COLORS) 
- Git status and tab completion
- Available themes: nord (default), monokai, solarized-dark, solarized-light

Change theme by modifying `themes.selected` in `home.nix`.

### Services Architecture
Complex services (like rclone) use:
- Modular imports for different aspects (mount, launchd, utilities)
- Activation scripts with dependency ordering (`lib.hm.dag.entryAfter`)
- Comprehensive logging to `~/nix-flakes/logs/`
- State management through hash files and status tracking

### Host-Specific Configuration
The `modules/host-config/` module detects machine type at runtime and applies appropriate settings like Git signing keys. Machine detection happens through activation scripts that write to `~/.nix-host-*` files.

### Secrets Management
Uses agenix for encrypted secrets stored in `modules/agenix/`. Secrets are decrypted during activation scripts before dependent services start. The rclone configuration is the primary encrypted secret.

## Development Workflow

1. Make changes to modules in `modules/` directory
2. Test with `home-manager build --flake . --impure` 
3. Apply with `home-manager switch --flake . --impure`
4. For system changes, use `darwin-rebuild switch --flake .#$(hostname) --impure`
5. Format code with `nixpkgs-fmt` and lint with `statix check`

The repository includes comprehensive logging and debug utilities for troubleshooting service issues, particularly for the rclone mounting system.