# ZSH Module

This module configures ZSH shell with a comprehensive set of features for a productive development environment.

## Features

- Powerlevel10k theme with instant prompt
- Intelligent color handling in terminal
- Comprehensive Git and Kubernetes integration
- Numerous productivity helpers and aliases

## Theme Integration

This module integrates with the themes module to ensure consistent coloring between the prompt, ls output, and terminal completion.

To change themes, modify the `themes.selected` option in your home.nix:

```nix
{
  imports = [
    ./modules/themes
    ./modules/zsh
    # Other modules...
  ];
  
  # Select your theme
  themes.selected = "nord"; # Options: nord, monokai, solarized-dark, solarized-light
}
```

To view the current theme information, use the `show_current_theme` function in your shell.
