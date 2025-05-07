# VSCode Module for Nix Home Manager

This module configures Visual Studio Code with extensions and settings using a pure Nix approach.

## Structure

- `default.nix`: Main VSCode configuration
- `extensions.nix`: Extension management
- `settings.nix`: User settings
- `darwin.nix`: macOS-specific configuration with proper app linking

## Key Features

- Uses the `nix-vscode-extensions` overlay to manage extensions
- Sets up proper activation hooks for macOS compatibility
- Manages settings declaratively through Nix

## Usage

This module is automatically included through `home.nix`. To rebuild:

```
cd ~/nix-flakes
home-manager switch --flake .#shavakan
```

## Troubleshooting

If VSCode is missing from your applications:

1. Check the application was built correctly:
   ```
   home-manager build --flake .#shavakan
   ```

2. Manual linking might be required if the activation script fails:
   ```nix
   # In your Home Manager config
   home.activation.linkVSCode = lib.hm.dag.entryAfter ["writeBoundary"] ''
     VSCODE_PATH=$(find $HOME/.nix-profile -name "Visual Studio Code.app" -type d)
     if [ -n "$VSCODE_PATH" ]; then
       ln -sf "$VSCODE_PATH" "/Applications/Visual Studio Code.app"
     fi
   '';
   ```

3. Verify the extensions are being installed properly:
   ```
   code --list-extensions
   ```
