# Zsh Configuration Module

This module provides a comprehensive, declarative Zsh configuration using Nix and home-manager.

## Features

- **Powerlevel10k Theme**: Modern, fast, and highly customizable prompt
- **Syntax Highlighting**: Real-time syntax highlighting for better readability
- **Auto-suggestions**: Fish-like command suggestions based on history
- **Auto-completion**: Tab completion with context-aware behavior
- **Directory Navigation**: Advanced directory jumping with auto-cd
- **Git Integration**: Enhanced Git experience with aliases and status information
- **FZF Integration**: Fuzzy-finding for files, history, and more
- **Direnv Support**: Automatic loading of environment variables per directory

## Customization

To customize this configuration:

1. Edit the `default.nix` file directly
2. Adjust shell aliases in the `shellAliases` attribute set
3. Add environment variables in the `initExtra` string
4. Configure Oh-My-Zsh plugins in the `oh-my-zsh.plugins` list

## Extensions

This module integrates several key Zsh extensions:

- **FZF**: Fuzzy finder for files, history, etc.
- **Direnv**: Directory-specific environment variables
- **Powerlevel10k**: Feature-rich prompt theme
- **Zsh Syntax Highlighting**: Command highlighting
- **Zsh Autosuggestions**: Fish-like automatic suggestions

## Usage

This module is automatically imported in the main `home.nix` file. After changing configuration, apply with:

```bash
LANG=en_US.UTF-8 home-manager switch --flake . --impure
```

## Configuration Files

- **default.nix**: Main Zsh configuration
- **.p10k.zsh**: Powerlevel10k theme configuration (generated on first run)

## Useful Shortcuts

The configuration includes several helpful keyboard shortcuts:

- **Ctrl+R**: Fuzzy search command history
- **Ctrl+T**: Fuzzy find files in current directory
- **Alt+C**: Fuzzy find and CD into subdirectories
- **Tab**: Smart completion and suggestions

## Requirements

- Nix package manager
- home-manager
