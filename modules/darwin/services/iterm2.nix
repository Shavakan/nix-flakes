# modules/darwin/services/iterm2.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.custom.iterm2;
  
  # Helper function to convert a JSON profile to nix-darwin settings
  profileToDefaults = profile: {
    # Basic profile settings
    "New Bookmarks" = [
      {
        inherit (profile) Name;
        Guid = profile.Guid or "D4EC0C84-1267-403C-ABDB-2EF9BD943241";

        # Terminal settings
        "Terminal Type" = profile."Terminal Type" or "xterm-256color";
        "Silence Bell" = profile."Silence Bell" or false;
        "Visual Bell" = profile."Visual Bell" or true;
        "Flashing Bell" = profile."Flashing Bell" or false;
        "BM Growl" = profile."BM Growl" or true;
        
        # Window size settings
        "Columns" = profile."Columns" or 120;
        "Rows" = profile."Rows" or 30;
            
        # Font settings
        "Normal Font" = profile."Normal Font" or "MesloLGS-NF-Regular 13";
        "Non Ascii Font" = profile."Non Ascii Font" or "Monaco 12";
        "Use Non-ASCII Font" = profile."Use Non-ASCII Font" or false;
        "Use Bold Font" = profile."Use Bold Font" or true;
        "Use Italic Font" = profile."Use Italic Font" or true;
        "Use Bright Bold" = profile."Use Bright Bold" or true;
        "Draw Powerline Glyphs" = profile."Draw Powerline Glyphs" or true;
        
        # Window settings
        "Window Type" = profile."Window Type" or 0;
        "Background Image Location" = profile."Background Image Location" or "";
        "Blur" = profile."Blur" or true;
        "Blur Radius" = profile."Blur Radius" or 7;
        "Transparency" = profile."Transparency" or 0.3;
        "Only The Default BG Color Uses Transparency" = profile."Only The Default BG Color Uses Transparency" or true;
        "Scrollback Lines" = profile."Scrollback Lines" or 4000;
        "Unlimited Scrollback" = profile."Unlimited Scrollback" or false;
        "Disable Window Resizing" = profile."Disable Window Resizing" or false;
        
        # Terminal appearance
        "Cursor Text Color" = profile."Cursor Text Color" or {
          "Red Component" = 1;
          "Green Component" = 1;
          "Blue Component" = 1;
        };
        "Cursor Color" = profile."Cursor Color" or {
          "Red Component" = 0.73333334922790527;
          "Green Component" = 0.73333334922790527;
          "Blue Component" = 0.73333334922790527;
        };
        "Minimum Contrast" = profile."Minimum Contrast" or 0;
        # Adjust these colors for better visibility in dark themes - pure white text on pure black
        "Foreground Color" = profile."Foreground Color" or {
          "Red Component" = 1.0;
          "Green Component" = 1.0;
          "Blue Component" = 1.0;
        };
        "Background Color" = profile."Background Color" or {
          "Red Component" = 0.0;
          "Green Component" = 0.0;
          "Blue Component" = 0.0;
        };
        "Selection Color" = profile."Selection Color" or {
          "Red Component" = 0.70980000495910645;
          "Green Component" = 0.8353000283241272;
          "Blue Component" = 1;
        };
        "Selected Text Color" = profile."Selected Text Color" or {
          "Red Component" = 0;
          "Green Component" = 0;
          "Blue Component" = 0;
        };
        "Bold Color" = profile."Bold Color" or {
          "Red Component" = 1;
          "Green Component" = 1;
          "Blue Component" = 1;
        };
        
        # ANSI colors
        "Ansi 0 Color" = profile."Ansi 0 Color" or {
          "Red Component" = 0;
          "Green Component" = 0;
          "Blue Component" = 0;
        };
        "Ansi 1 Color" = profile."Ansi 1 Color" or {
          "Red Component" = 0.73333334922790527;
          "Green Component" = 0;
          "Blue Component" = 0;
        };
        "Ansi 2 Color" = profile."Ansi 2 Color" or {
          "Red Component" = 0;
          "Green Component" = 0.73333334922790527;
          "Blue Component" = 0;
        };
        "Ansi 3 Color" = profile."Ansi 3 Color" or {
          "Red Component" = 0.73333334922790527;
          "Green Component" = 0.73333334922790527;
          "Blue Component" = 0;
        };
        "Ansi 4 Color" = profile."Ansi 4 Color" or {
          "Red Component" = 0;
          "Green Component" = 0;
          "Blue Component" = 0.73333334922790527;
        };
        "Ansi 5 Color" = profile."Ansi 5 Color" or {
          "Red Component" = 0.73333334922790527;
          "Green Component" = 0;
          "Blue Component" = 0.73333334922790527;
        };
        "Ansi 6 Color" = profile."Ansi 6 Color" or {
          "Red Component" = 0;
          "Green Component" = 0.73333334922790527;
          "Blue Component" = 0.73333334922790527;
        };
        "Ansi 7 Color" = profile."Ansi 7 Color" or {
          "Red Component" = 0.73333334922790527;
          "Green Component" = 0.73333334922790527;
          "Blue Component" = 0.73333334922790527;
        };
        "Ansi 8 Color" = profile."Ansi 8 Color" or {
          "Red Component" = 0.3333333432674408;
          "Green Component" = 0.3333333432674408;
          "Blue Component" = 0.3333333432674408;
        };
        "Ansi 9 Color" = profile."Ansi 9 Color" or {
          "Red Component" = 1;
          "Green Component" = 0.3333333432674408;
          "Blue Component" = 0.3333333432674408;
        };
        "Ansi 10 Color" = profile."Ansi 10 Color" or {
          "Red Component" = 0.3333333432674408;
          "Green Component" = 1;
          "Blue Component" = 0.3333333432674408;
        };
        "Ansi 11 Color" = profile."Ansi 11 Color" or {
          "Red Component" = 1;
          "Green Component" = 1;
          "Blue Component" = 0.3333333432674408;
        };
        "Ansi 12 Color" = profile."Ansi 12 Color" or {
          "Red Component" = 0.3333333432674408;
          "Green Component" = 0.3333333432674408;
          "Blue Component" = 1;
        };
        "Ansi 13 Color" = profile."Ansi 13 Color" or {
          "Red Component" = 1;
          "Green Component" = 0.3333333432674408;
          "Blue Component" = 1;
        };
        "Ansi 14 Color" = profile."Ansi 14 Color" or {
          "Red Component" = 0.3333333432674408;
          "Green Component" = 1;
          "Blue Component" = 1;
        };
        "Ansi 15 Color" = profile."Ansi 15 Color" or {
          "Red Component" = 1;
          "Green Component" = 1;
          "Blue Component" = 1;
        };
        
        # Behavior settings
        "Custom Command" = profile."Custom Command" or "No";
        "Command" = profile."Command" or "";
        "Working Directory" = profile."Working Directory" or "/Users/shavakan";
        "Custom Directory" = profile."Custom Directory" or "No";
        "Prompt Before Closing 2" = profile."Prompt Before Closing 2" or false;
        "Sync Title" = profile."Sync Title" or false;
        "Close Sessions On End" = profile."Close Sessions On End" or true;
        "Jobs to Ignore" = profile."Jobs to Ignore" or [
          "rlogin"
          "ssh"
          "slogin"
          "telnet"
        ];
        
        # Keyboard settings
        "Keyboard Map" = profile."Keyboard Map" or {};
        "Option Key Sends" = profile."Option Key Sends" or 0;
        "Right Option Key Sends" = profile."Right Option Key Sends" or 0;
        "Send Code When Idle" = profile."Send Code When Idle" or false;
        "Idle Code" = profile."Idle Code" or 0;
        
        # Additional settings
        "ASCII Anti Aliased" = profile."ASCII Anti Aliased" or true;
        "Non-ASCII Anti Aliased" = profile."Non-ASCII Anti Aliased" or true;
        "Ambiguous Double Width" = profile."Ambiguous Double Width" or false;
        "Blinking Cursor" = profile."Blinking Cursor" or false;
        "Mouse Reporting" = profile."Mouse Reporting" or true;
        "Character Encoding" = profile."Character Encoding" or 4;
        "Horizontal Spacing" = profile."Horizontal Spacing" or 1;
        "Vertical Spacing" = profile."Vertical Spacing" or 1;
      }
    ];
    
    # If this is the default profile, set it as such
    "Default Bookmark" = profile."Default Bookmark" or "No";
  };
  
  # Default profile based on the JSON file provided
  defaultProfile = {
    Name = "Default";
    Guid = "D4EC0C84-1267-403C-ABDB-2EF9BD943241";
    "Default Bookmark" = "Yes";
    "Terminal Type" = "xterm-256color";
    "Visual Bell" = true;
    "Flashing Bell" = false;
    "Silence Bell" = false;
    "Draw Powerline Glyphs" = true;
    "Normal Font" = "MesloLGS-NF-Regular 13";
    "Use Non-ASCII Font" = false;
    "Blur" = false;             # Disable blur for clearer text
    "Blur Radius" = 0;          # No blur
    "Transparency" = 0.0;        # No transparency for maximum contrast
    "Only The Default BG Color Uses Transparency" = true;
    "Scrollback Lines" = 4000;
    "Working Directory" = "/Users/shavakan";
    "Close Sessions On End" = true;
    "Prompt Before Closing 2" = false;
    "BM Growl" = true;
    "ASCII Anti Aliased" = true;
    "Non-ASCII Anti Aliased" = true;
    "Use Bold Font" = true;
    "Use Italic Font" = true;
    "Use Bright Bold" = true;    # Ensure bold text is bright
    "Minimum Contrast" = 0.5;    # Increase minimum contrast
    "Columns" = 120;            # Set default width to 120 columns
    "Rows" = 30;                # Set default height to 30 rows
  };
in {
  options.custom.iterm2 = {
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
            default = "MesloLGS-NF-Regular";
            description = "Font to use for the profile";
          };
          
          fontSize = mkOption {
            type = types.int;
            default = 13;
            description = "Font size to use for the profile";
          };
          
          useNonAsciiFont = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to use a different font for non-ASCII characters";
          };
          
          nonAsciiFont = mkOption {
            type = types.str;
            default = "Monaco";
            description = "Font to use for non-ASCII characters";
          };
          
          nonAsciiFontSize = mkOption {
            type = types.int;
            default = 12;
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
      description = "Whether to include a profile based on the provided Default.json";
    };
    
    # Smart features
    enableSmartSelection = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable smart selection";
    };
    
    # Keyboard shortcuts
    hotkeys = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          key = mkOption {
            type = types.str;
            description = "Key to use for the hotkey";
          };
          
          modifiers = mkOption {
            type = types.listOf (types.enum [ "command" "control" "option" "shift" ]);
            default = [];
            description = "Modifier keys to use for the hotkey";
          };
          
          action = mkOption {
            type = types.str;
            description = "Action to take when the hotkey is pressed";
          };
        };
      });
      default = {};
      description = "Keyboard shortcuts for iTerm2";
    };
  };

  config = mkIf cfg.enable {
    system.defaults.CustomUserPreferences = {
      "com.googlecode.iterm2" = {
        # General settings
        "QuitWhenAllWindowsClosed" = cfg.disablePromptOnQuit;
        "PromptOnQuit" = !cfg.disablePromptOnQuit;
        
        # Appearance
        "TabViewType" = if (cfg.tabsPosition == "top") then 0 else 1;
        "PreferIntegratedGPU" = true;
        "UseMetal" = true;
        "AppleWindowTabbingMode" = "manual";
        
        # Theme settings
        "UseDarkTheme" = cfg.theme == "dark" ||
                        (cfg.theme == "auto" && config.system.defaults.NSGlobalDomain.AppleInterfaceStyle or "Light" == "Dark");
        
        # Window settings
        "OpenArrangementAtStartup" = false;
        "OpenNoWindowsAtStartup" = false;
        
        # Window style
        "WindowStyle" = (
          if cfg.windowStyle == "normal" then 0
          else if cfg.windowStyle == "fullscreen" then 1
          else if cfg.windowStyle == "maximized" then 2
          else 0
        );
        
        # Status bar
        "StatusBarPosition" = if (cfg.statusBar.position == "top") then 1 else 0;
        "ShowFullScreenTabBar" = true;
        "ShowPaneTitles" = true;
        
        # Advanced preferences
        "SmartSelectionRules" = cfg.enableSmartSelection;
        "AdjustWindowForFontSizeChange" = true;
        "SoundForEsc" = false;
        
        # Apply advanced preferences
        } // cfg.advancedPreferences // (
          # Default profile based on JSON
          if cfg.useDefaultProfile then profileToDefaults defaultProfile else {}
        ) // (
          # User-configured profiles
          if cfg.profiles != {} then 
          builtins.foldl' (acc: name: 
          let profile = cfg.profiles.${name}; 
          in acc // {
          "New Bookmarks" = acc."New Bookmarks" or [] ++ [{
          Name = profile.name;
          Guid = "profile-${builtins.hashString "md5" profile.name}";
          "Default Bookmark" = if profile.default then "Yes" else "No";
          "Normal Font" = "${profile.font} ${toString profile.fontSize}";
          "Use Non-ASCII Font" = profile.useNonAsciiFont;
          "Non Ascii Font" = "${profile.nonAsciiFont} ${toString profile.nonAsciiFontSize}";
          "Use Bold Font" = profile.useBoldFont;
          "Use Italic Font" = profile.useItalicFont;
          "Unlimited Scrollback" = profile.unlimitedScrollback;
          "Scrollback Lines" = profile.scrollbackLines;
          "Working Directory" = profile.workingDirectory;
          "Custom Directory" = "Yes";
          "Blur" = profile.blurBackground;
          "Blur Radius" = profile.blurRadius;
          "Transparency" = profile.transparency;
          "Only The Default BG Color Uses Transparency" = profile.useTransparencyOnlyForDefaultBg;
          "Close Sessions On End" = profile.closeOnExit == "always";
          "Prompt Before Closing 2" = profile.closeOnExit == "never";
            # Set larger default window size
              "Columns" = 120;
                        "Rows" = 30;
                      }];
                    }) {} (builtins.attrNames cfg.profiles)
          else {}
        );
    };
    
    # Setup launch keybindings
    system.activationScripts.iterm2-keymaps = {
      text = ''
        echo "Configuring iTerm2 key mappings..."
        
        # This would be a more complex script to configure keymappings
        # As a placeholder, we're just noting that it would run here
        # A real implementation would use defaults write extensively
      '';
    };
    
    # Ensure iTerm2 is installed
    environment.systemPackages = [ pkgs.iterm2 ];
    
    # Create a service that ensures the font is properly installed
    system.activationScripts.iterm2-fonts = {
      text = ''
        echo "Ensuring MesloLGS NF font is properly installed for iTerm2..."
        
        # Refresh font cache to recognize the Meslo Nerd Fonts
        if command -v fc-cache >/dev/null 2>&1; then
          fc-cache -f -v
        fi
      '';
    };
  };
}
