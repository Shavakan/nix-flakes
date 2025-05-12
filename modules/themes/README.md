# Terminal Themes Module

This module provides centralized theme management for your Nix-based terminal environment using a pure Nix approach without any shell scripts.

## Features

- Unified theme definitions that work across modules
- Theme selection through a simple Nix option
- Consistent colors across ZSH prompt, directory listings, and completions
- No shell scripts or external dependencies

## Available Themes

- `nord`: Nord theme with blue/cyan accents (default)
- `monokai`: Monokai theme with vibrant colors
- `solarized-dark`: Solarized Dark theme
- `solarized-light`: Solarized Light theme

## Usage

Add this module to your `home.nix` and set your preferred theme:

```nix
{
  imports = [
    ./modules/themes
    # Other modules...
  ];
  
  # Select your theme
  themes.selected = "nord"; # Options: nord, monokai, solarized-dark, solarized-light
}
```

## Theme Information

To view your current theme configuration, use the `show_current_theme` function in your ZSH shell.

