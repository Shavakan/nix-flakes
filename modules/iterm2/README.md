# iTerm2 Configuration for Nix Home Manager

This module configures iTerm2 through home-manager using a stable approach that works around common issues.

## Features

- Ensures stable iTerm2 launch from Spotlight/Launchpad
- Configures proper font settings (MesloLGS NF and NanumGothicCoding)
- Creates Default and Work profiles
- Registers with macOS Launch Services correctly

## Troubleshooting

If iTerm2 crashes on launch, try these steps:

1. First, run the emergency fix script:
   ```
   sh ~/nix-flakes/scripts/emergency-fix-iterm.sh
   ```

2. If that doesn't work, try the font fix script:
   ```
   sh ~/nix-flakes/scripts/fix-fonts-and-spotlight.sh
   ```

3. Re-apply home-manager configuration:
   ```
   cd ~/nix-flakes && LANG=en_US.UTF-8 home-manager switch --flake . --impure
   ```

4. Check Console.app for any iTerm2 crash logs and look for specific error messages.

5. If issues persist, try:
   ```
   rm -f ~/Library/Preferences/com.googlecode.iterm2.plist
   rm -rf ~/Library/Application\ Support/iTerm2
   rm -rf ~/Library/Saved\ Application\ State/com.googlecode.iterm2.savedState
   rm -rf ~/Library/Caches/com.googlecode.iterm2
   killall cfprefsd
   ```

## Fonts

This configuration uses:
- Main font: MesloLGS NF Regular (for Powerlevel10k compatibility)
- Non-ASCII font: NanumGothicCoding (for Korean characters)

These fonts are installed system-wide through nix-darwin in modules/darwin/default.nix:
```nix
environment.systemPackages = with pkgs; [
  # Fonts for system-wide availability
  meslo-lgs-nf # Meslo Nerd Font patched for Powerlevel10k
  nanum # Nanum Korean font set (includes Nanum Gothic Coding)
  # ...
];
```

If fonts don't appear correctly, you can manually apply them with:
```
~/nix-flakes/scripts/apply-iterm-fonts.sh
```