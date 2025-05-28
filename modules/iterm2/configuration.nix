# modules/iterm2/configuration.nix
{ config, lib, pkgs, ... }:

{
  # Enable iTerm2 configuration
  programs.iterm2 = {
    enable = true;
    disablePromptOnQuit = true;
    theme = "dark"; # Fixed theme instead of auto to prevent crashes
    tabsPosition = "top";
    windowStyle = "normal";
    enableSmartSelection = true;

    # Use the default profile
    useDefaultProfile = true;

    # Configure profiles
    profiles = {
      "Default" = {
        default = true;
        name = "Default";
        # Using MesloLGS NF for better terminal experience
        font = "MesloLGS-NF-Regular";
        fontSize = 13;
        useBoldFont = true;
        useItalicFont = true;
        unlimitedScrollback = true;
        scrollbackLines = 100000; # Still set a high value even though unlimited is enabled
        workingDirectory = "~/";
        blurBackground = false; # Disable blur which can cause issues
        transparency = 0.0; # Disable transparency
        useTransparencyOnlyForDefaultBg = false;
        closeOnExit = "always";
      };
    };

    # Advanced preferences
    advancedPreferences = {
      # Mouse behavior
      "AlternateMouseScroll" = true;
      "FocusFollowsMouse" = false;
      
      # Terminal behavior
      "AutoCommandHistory" = true;
      "SoundForEsc" = false;
      
      # UI preferences
      "HideScrollbar" = false;
      "DisableFullscreenTransparency" = true;
      "SplitPaneDimmingAmount" = 0.0;
      "EnableProxyIcon" = true;
      "EnableRendezvous" = false;
      "HideMenuBarInFullscreen" = true;
      "SUEnableAutomaticChecks" = true;
      "DisableWindowSizeSnap" = false;
      
      # Disable Metal renderer to prevent crashes
      "UseMetal" = false;
      "UseAdaptiveFrameRate" = false;
      "MetalMaximizeThroughput" = false;
      
      # Disable theme automatic switching and appearance changes which can cause crashes
      "AppleInterfaceStyleSwitchesAutomatically" = false;
      "PreventEscapeSequenceFromClearingHistory" = true;
      "NoSyncDoNotWarnBeforeMultilinePaste" = true;
      "NoSyncDoNotWarnBeforeMultilinePaste_selection" = true;
      "MinimalTheme" = false; # Disable minimal theme which can cause crashes
      
      # Tab styling
      "TabStyleWithAutomaticOption" = 0; # Simple tab style
      "TabViewType" = 0; # Tabs on top
      "HideTab" = false;
      "ShowFullScreenTabBar" = true;
      "ShowPaneTitles" = true;
      "HideTabNumber" = false;
      "HideTabCloseButton" = false;
      "FlashTabBarInFullscreen" = true;
      "StretchTabsToFillBar" = true;
      # Window size preferences
      "WindowStyle" = 0;
      "InitialWindowSize" = {
        Width = 1200;
        Height = 800;
      };
      "OpenNewWindowsHere" = true;
      "QuitWhenAllWindowsClosed" = false; # Don't quit when windows close
      "PromptOnQuit" = false; # Don't prompt on quit
    };

    # Status bar configuration - disable status bar which can cause issues
    statusBar = {
      show = false;
      position = "bottom";
      components = [
        "CurrentDirectory"
      ];
    };
  };
}
