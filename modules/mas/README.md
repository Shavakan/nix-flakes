# Mac App Store Module

This module provides integration with the Mac App Store through the `mas` CLI tool, allowing you to declaratively manage Mac App Store applications in your Nix configuration.

## Usage

Add the module to your flake inputs and then configure it in your home.nix:

```nix
{
  services.mas = {
    enable = true;
    
    # Your Apple ID for Mac App Store
    appleId = "your-email@example.com"; 
    
    # Apps to install from Mac App Store
    apps = {
      "AppName1" = 123456789;
      "AppName2" = 987654321;
    };
  };
}
```

## Finding App IDs

To find the ID for an app you want to install, you can search for it using:

```bash
mas search "App Name"
```

## Options

- `enable` - Whether to enable Mac App Store integration
- `appleId` - Email address to sign in to Mac App Store (optional if already signed in)
- `apps` - Attribute set of app names to their Mac App Store IDs

## Notes

- The module operates silently with no console output
- All activity is logged to `~/nix-flakes/logs/mas.log`
- Manual sign-in via the Mac App Store UI app is recommended
- The module checks if apps are already installed by looking in `/Applications/`
- For best results, sign in to the Mac App Store app before running home-manager