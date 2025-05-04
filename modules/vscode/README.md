# VS Code Extensions Management with Nix

This module enables declarative management of VS Code extensions and settings using Nix. It uses the `nix-vscode-extensions` overlay to access both standard nixpkgs extensions and VS Code Marketplace extensions.

## Features

- Declarative management of VS Code extensions
- Persistent settings configuration via Nix
- Access to both nixpkgs and VS Code Marketplace extensions
- Automatic updates through the nix-community repository

## Directory Structure

- `default.nix` - Main VS Code configuration
- `extensions.nix` - Extensions management
- `settings.nix` - User settings configuration
- `extract-extensions.sh` - Helper script for extension extraction

## Managing Extensions

### Adding New Extensions

To add a new extension, edit `extensions.nix` and add the extension to the appropriate list:

1. If the extension is available in nixpkgs, add it to the first list:

```nix
(with pkgs.vscode-extensions; [
  # Add nixpkgs extensions here
  publisher.name
])
```

2. If the extension is not in nixpkgs, add it to the marketplace list:

```nix
++ (with pkgs.vscode-marketplace; [
  # Add marketplace extensions here
  publisher.name
])
```

### Checking Extension Availability

To check if an extension is available in nixpkgs, run:

```bash
nix-env -f '<nixpkgs>' -qaP -A vscode-extensions
```

### Temporarily Using Manual Extensions

If you need to temporarily install extensions manually for testing:

1. Edit `default.nix` and change `mutableExtensionsDir = false;` to `mutableExtensionsDir = true;`
2. Run `home-manager switch`
3. Install extensions manually through VS Code
4. When done, use the extract-extensions.sh script to get the Nix configuration
5. Change back to `mutableExtensionsDir = false;` and add the extensions to your Nix configuration

## Updating Settings

To modify VS Code settings, edit `settings.nix`. This file uses the Nix attribute set format to represent the JSON settings.

### JSON to Nix Conversion Rules

- JSON object `{}` → Nix attribute set `{}`
- JSON array `[]` → Nix list `[]`
- JSON string `"value"` → Nix string `"value"`
- JSON number `42` → Nix number `42`
- JSON boolean `true`/`false` → Nix boolean `true`/`false`
- JSON null → Nix `null`

Example:
```nix
{
  "editor.fontSize" = 14;
  "editor.fontFamily" = "Hack, monospace";
  "workbench.colorTheme" = "Dark+";
}
```

## Applying Changes

After making changes to any of the files, apply the changes by running:

```bash
home-manager switch
```

## Troubleshooting

### Missing Extensions

If extensions appear to be missing after applying changes:

1. Check if the extension is available in nixpkgs or needs to be accessed via marketplace
2. Verify the publisher and name are correct (they're case-sensitive)
3. Confirm that the syntax in your Nix configuration is correct

### Binary Extensions

Some extensions with binary components might not work properly. Options to fix this:

1. Use the FHS-enabled version of VS Code (adds some