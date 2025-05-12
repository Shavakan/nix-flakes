# modules/darwin/services/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./stage-manager.nix
    ./iterm2.nix
  ];

  # Configure the custom Stage Manager service
  custom.stageManager = {
    enable = true;
    keyboard = {
      enableShortcuts = true;
      shortcuts = [ "cmd + alt - s" ];
    };
    createDesktopShortcut = true;
    defaultEnabled = true;
  };

  # Configure iTerm2
  custom.iterm2 = {
    enable = true;
    disablePromptOnQuit = true;
    theme = "auto";
    tabsPosition = "top";
    windowStyle = "normal";
    enableSmartSelection = true;

    # Use the Default.json profile exactly as provided
    useDefaultProfile = true;

    # Add any additional profiles as needed
    profiles = {
      "Default" = {
        default = true;
        name = "Default";
        font = "MesloLGS-NF-Regular";
        fontSize = 13;
        useNonAsciiFont = false;
        useBoldFont = true;
        useItalicFont = true;
        unlimitedScrollback = false;
        scrollbackLines = 4000;
        workingDirectory = "~/";
        blurBackground = false; # Disable blur for clearer text
        blurRadius = 0; # No blur
        transparency = 0.0; # No transparency for maximum contrast
        useTransparencyOnlyForDefaultBg = true;
        closeOnExit = "always";
      };
      "Work" = {
        default = false;
        name = "Work";
        font = "MesloLGS-NF-Regular";
        fontSize = 13;
        useNonAsciiFont = false;
        nonAsciiFont = "Monaco";
        nonAsciiFontSize = 12;
        cursorType = "box";
        colorScheme = "Solarized Dark";
        useBoldFont = true;
        useItalicFont = true;
        unlimitedScrollback = false;
        scrollbackLines = 4000;
        workingDirectory = "~/workspace";
        blurBackground = true;
        blurRadius = 7;
        transparency = 0.3;
        useTransparencyOnlyForDefaultBg = true;
        closeOnExit = "always";
      };
    };

    # Advanced preferences
    advancedPreferences = {
      "AlternateMouseScroll" = true;
      "AutoCommandHistory" = true;
      "SoundForEsc" = false;
      "FocusFollowsMouse" = false;
      "HideScrollbar" = false;
      "DisableFullscreenTransparency" = false;
      "SplitPaneDimmingAmount" = 0.4;
      "FlashTabBarInFullscreen" = true;
      "EnableProxyIcon" = true;
      "EnableRendezvous" = false;
      "HideMenuBarInFullscreen" = true;
      "SUEnableAutomaticChecks" = true;
      "ShowFullScreenTabBar" = true;
      "ShowPaneTitles" = true;
      "HideTabNumber" = false;
      "HideTabCloseButton" = false;
      "DisableWindowSizeSnap" = false;
      # Additional window size preferences
      "WindowStyle" = 0;
      "InitialWindowSize" = "{
        Width = 1200;
        Height = 800;
      }";
      "OpenNewWindowsHere" = true;
      "QuitWhenAllWindowsClosed" = true;
      "BootstrapDimensions" = "{
        Width = 1200;
        Height = 800;
      }";
    };

    # Status bar configuration
    statusBar = {
      show = true;
      position = "bottom";
      components = [
        "CurrentDirectory"
        "CPU"
        "Memory"
        "Battery"
        "DateTime"
      ];
    };
  };
}
