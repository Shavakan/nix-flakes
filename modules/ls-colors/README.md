# LS_COLORS Module

This module configures LS_COLORS for consistent terminal coloring. It works with the themes module to provide consistent terminal colors.

## Features

- Uses `dircolors` for proper LS_COLORS integration
- Supports `vivid` for generating LS_COLORS from theme definitions
- Compatible with ZSH completion coloring

## Usage

Add this module to your `home.nix` and set your preferred theme in the config:

```nix
{
  imports = [
    ./modules/themes
    ./modules/ls-colors
    # Other modules...
  ];
  
  # Select your theme
  themes.selected = "nord"; # Options: nord, monokai, solarized-dark, solarized-light
}
```
