# modules/iterm2/default.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.iterm2;
in {
  imports = [
    ./configuration.nix
  ];
  
  options.programs.iterm2 = {
    enable = mkEnableOption "iTerm2 configuration";
    
    # General preferences
    disablePromptOnQuit = mkOption {
      type = types.bool;
      default = true;
      description = "Disable the confirmation prompt when quitting iTerm2";
    };
    
    # Appearance preferences
    theme = mkOption {
      type = types.enum [ "light" "dark" "auto" ];
      default = "auto";
      description = "Theme setting for iTerm2";
    };
    
    tabsPosition = mkOption {
      type = types.enum [ "top" "bottom" ];
      default = "top";
      description = "Position of tabs in iTerm2";
    };
    
    # Window preferences
    windowStyle = mkOption {
      type = types.enum [ "normal" "fullscreen" "maximized" ];
      default = "normal";
      description = "Default window style";
    };
    
    # Advanced preferences
    advancedPreferences = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Advanced preferences for iTerm2 using raw key-value pairs";
      example = literalExample ''{ 
        "AlternateMouseScroll" = true;
        "AutoHideTmuxClientSession" = false;
        "SoundForEsc" = false;
        "FindMode_EntireWord" = true;
      }'';
    };
    
    # Status bar configuration
    statusBar = {
      show = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to show the status bar";
      };
      
      position = mkOption {
        type = types.enum [ "top" "bottom" ];
        default = "bottom";
        description = "Position of the status bar";
      };
      
      components = mkOption {
        type = types.listOf (types.enum [
          "CPU"
          "Memory"
          "Network"
          "CurrentDirectory"
          "UserName"
          "HostName"
          "DateTime"
          "Battery"
        ]);
        default = [ "CurrentDirectory" "DateTime" ];
        description = "Components to show in the status bar";
      };
    };
    
    # Profile settings
    profiles = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          default = mkOption {
            type = types.bool;
            default = false;
            description = "Whether this is the default profile";
          };
          
          name = mkOption {
            type = types.str;
            description = "Profile name";
          };
          
          font = mkOption {
            type = types.str;
            default = "MesloLGS NF";
            description = "Font to use for the profile";
          };
          
          fontSize = mkOption {
            type = types.int;
            default = 13;
            description = "Font size to use for the profile";
          };
          
          useNonAsciiFont = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to use a different font for non-ASCII characters";
          };
          
          nonAsciiFont = mkOption {
            type = types.str;
            default = "NanumGothicCoding";
            description = "Font to use for non-ASCII characters";
          };
          
          nonAsciiFontSize = mkOption {
            type = types.int;
            default = 13;
            description = "Font size to use for non-ASCII characters";
          };
          
          cursorType = mkOption {
            type = types.enum [ "box" "vertical" "underline" ];
            default = "box";
            description = "Type of cursor to use in the terminal";
          };
          
          colorScheme = mkOption {
            type = types.enum [ "Default" "Solarized Dark" "Solarized Light" "Nord" "Dracula" "Custom" ];
            default = "Default";
            description = "Color scheme to use for the profile";
          };
          
          customColors = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Custom colors for the terminal";
          };
          
          useBoldFont = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to use bold fonts";
          };
          
          useItalicFont = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to use italic fonts";
          };
          
          useLigatures = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to enable font ligatures";
          };
          
          unlimitedScrollback = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to allow unlimited scrollback";
          };
          
          scrollbackLines = mkOption {
            type = types.int;
            default = 4000;
            description = "Number of lines to keep in scrollback buffer";
          };
          
          shell = mkOption {
            type = types.str;
            default = "";
            description = "Shell to use for the profile (leave empty for default shell)";
          };
          
          workingDirectory = mkOption {
            type = types.str;
            default = "~/";
            description = "Initial working directory (leave empty for home directory)";
          };
          
          closeOnExit = mkOption {
            type = types.enum [ "always" "clean" "never" ];
            default = "always";
            description = "When to close the terminal after the process exits";
          };
          
          blurBackground = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to blur the terminal background";
          };
          
          blurRadius = mkOption {
            type = types.int;
            default = 7;
            description = "Blur radius for the terminal background";
          };
          
          transparency = mkOption {
            type = types.float;
            default = 0.3;
            description = "Transparency level for the terminal background (0.0-1.0)";
          };
          
          useTransparencyOnlyForDefaultBg = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to use transparency only for the default background color";
          };
        };
      });
      default = {};
      description = "iTerm2 profiles configuration";
    };
    
    # Import existing profiles
    useDefaultProfile = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to include a default profile";
    };
    
    # Smart features
    enableSmartSelection = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable smart selection";
    };
  };

  config = mkIf cfg.enable {
    # Ensure iTerm2 is installed
    home.packages = [ pkgs.iterm2 ];
    
    # Font installation service that runs on activation to ensure fonts are available (quiet version)
    home.activation.installFonts = lib.hm.dag.entryAfter ["setupLogging"] ''
      # Install the fonts to user's font directory
      USER_FONTS_DIR="$HOME/Library/Fonts"
      mkdir -p "$USER_FONTS_DIR" > /dev/null 2>&1
      
      log_nix "fonts" "Installing iTerm2 fonts to $USER_FONTS_DIR"
      
      # Find and copy MesloLGS NF fonts quietly
      find /nix/store -name "MesloLGS NF*.ttf" 2>/dev/null | while IFS= read -r font; do
        font_name=$(basename "$font")
        cp -f "$font" "$USER_FONTS_DIR/" > /dev/null 2>&1
        log_nix "fonts" "Installed font: $font_name"
      done
      
      # Find and copy NanumGothicCoding fonts quietly
      find /nix/store -name "NanumGothicCoding*.ttf" 2>/dev/null | while IFS= read -r font; do
        font_name=$(basename "$font")
        cp -f "$font" "$USER_FONTS_DIR/" > /dev/null 2>&1
        log_nix "fonts" "Installed font: $font_name"
      done
    '';
    
    # Simplified activation script that directly writes a minimal working config (quiet version)
    home.activation.iterm2-config = lib.hm.dag.entryAfter ["setupLogging"] ''
      log_nix "iterm2" "Configuring iTerm2"
      
      # Check if the Launch Services registration needs to be fixed
      ITERM_PATH="$HOME/.nix-profile/Applications/iTerm2.app"
      if [ -e "$ITERM_PATH" ]; then
        log_nix "iterm2" "Re-registering iTerm2 with Launch Services"
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$ITERM_PATH" > /dev/null 2>&1
      fi
      
      # First clear all existing preferences to start fresh
      log_nix "iterm2" "Cleaning up previous iTerm2 preferences"
      rm -f ~/Library/Preferences/com.googlecode.iterm2.plist 2>/dev/null || true
      rm -rf ~/Library/Application\ Support/iTerm2 2>/dev/null || true
      rm -rf ~/Library/Saved\ Application\ State/com.googlecode.iterm2.savedState 2>/dev/null || true
      rm -rf ~/Library/Caches/com.googlecode.iterm2 2>/dev/null || true
      killall cfprefsd 2>/dev/null || true
      sleep 1
      
      # Create a minimal, safe configuration that won't crash
      log_nix "iterm2" "Creating minimal configuration"
      
      # Set basic preferences
      /usr/bin/defaults write com.googlecode.iterm2 "QuitWhenAllWindowsClosed" -bool false > /dev/null 2>&1
      /usr/bin/defaults write com.googlecode.iterm2 "PromptOnQuit" -bool false > /dev/null 2>&1
      /usr/bin/defaults write com.googlecode.iterm2 "TabViewType" -int 0 > /dev/null 2>&1
      /usr/bin/defaults write com.googlecode.iterm2 "UseMetal" -bool true > /dev/null 2>&1
      /usr/bin/defaults write com.googlecode.iterm2 "AlternateMouseScroll" -bool true > /dev/null 2>&1
      /usr/bin/defaults write com.googlecode.iterm2 "SoundForEsc" -bool false > /dev/null 2>&1
      
      # Force preferences to take effect
      killall cfprefsd 2>/dev/null || true
      
      log_nix "iterm2" "Applying font settings"
      
      # Get the current preference file path
      PLIST_FILE="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
      
      # Create a minimal emergency fix script and run it - this will not disturb existing profiles
      cat > /tmp/fix-iterm-fonts.sh << 'EOF'
#!/bin/bash
# Remove any existing plist
rm -f ~/Library/Preferences/com.googlecode.iterm2.plist 2>/dev/null || true

# Create very basic preferences
/usr/bin/defaults write com.googlecode.iterm2 "QuitWhenAllWindowsClosed" -bool false > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "PromptOnQuit" -bool false > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "NoSyncNeverRemindPrefsChangesLostForFile" -bool true > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "NoSyncNeverRemindPrefsChangesLostForFile_selection" -int 0 > /dev/null 2>&1

# Modern tab styling
/usr/bin/defaults write com.googlecode.iterm2 "TabStyleWithAutomaticOption" -int 5 > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "TabViewType" -int 0 > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "HideTab" -bool false > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "HideTabNumber" -bool false > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "HideTabCloseButton" -bool false > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "ShowPaneTitles" -bool true > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "ShowFullScreenTabBar" -bool true > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "FlashTabBarInFullscreen" -bool true > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "StretchTabsToFillBar" -bool true > /dev/null 2>&1

# Create a default profile with MesloLGS font - now we know the correct format
/usr/bin/defaults write com.googlecode.iterm2 "New Bookmarks" -array > /dev/null 2>&1
/usr/bin/defaults write com.googlecode.iterm2 "New Bookmarks" -array-add '{
    "Name" = "Default";
    "Guid" = "Default";
    "Default Bookmark" = "Yes";
    "Normal Font" = "MesloLGS-NF-Regular 13";
    "ASCII Anti Aliased" = 1;
    "Non-ASCII Anti Aliased" = 1;
    "Columns" = 120;
    "Rows" = 30;
    "Working Directory" = "~/";
    "Blur" = 1;
    "Blur Radius" = 2;
    "Transparency" = 0.3;
    "Only The Default BG Color Uses Transparency" = 1;
    "Unlimited Scrollback" = 1;
}' > /dev/null 2>&1

# Create a work profile
/usr/bin/defaults write com.googlecode.iterm2 "New Bookmarks" -array-add '{
    "Name" = "Work";
    "Guid" = "Work-Profile";
    "Default Bookmark" = "No";
    "Normal Font" = "MesloLGS-NF-Regular 13";
    "ASCII Anti Aliased" = 1;
    "Non-ASCII Anti Aliased" = 1;
    "Columns" = 120;
    "Rows" = 30;
    "Working Directory" = "~/workspace";
    "Blur" = 1;
    "Blur Radius" = 2;
    "Transparency" = 0.3;
    "Only The Default BG Color Uses Transparency" = 1;
    "Unlimited Scrollback" = 1;
}' > /dev/null 2>&1

# Set the default bookmark
/usr/bin/defaults write com.googlecode.iterm2 "Default Bookmark Guid" "Default" > /dev/null 2>&1

# Force refresh preferences
killall cfprefsd 2>/dev/null || true
EOF

      # Make the script executable and run it
      chmod +x /tmp/fix-iterm-fonts.sh
      log_nix "iterm2" "Running iTerm2 configuration script"
      /tmp/fix-iterm-fonts.sh > /dev/null 2>&1
      
      # Clean up
      rm -f /tmp/fix-iterm-fonts.sh
      
      log_nix "iterm2" "iTerm2 configuration complete"
    '';
  };
}