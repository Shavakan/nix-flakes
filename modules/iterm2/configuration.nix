# modules/iterm2/configuration.nix
{ config, lib, pkgs, ... }:

{
  # Enable iTerm2 configuration
  programs.iterm2 = {
    enable = true;
    disablePromptOnQuit = true;
    theme = "dark";
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
        useNonAsciiFont = false;
        useBoldFont = true;
        useItalicFont = true;
        unlimitedScrollback = true;
        scrollbackLines = 100000; # Still set a high value even though unlimited is enabled
        workingDirectory = "~/";
        blurBackground = true;
        blurRadius = 2;
        transparency = 0.3;
        useTransparencyOnlyForDefaultBg = true;
        closeOnExit = "always";
      };
    };

    # Advanced preferences
    advancedPreferences = {
      "AlternateMouseScroll" = true;
      "FocusFollowsMouse" = false;
      "AutoCommandHistory" = true;
      "SoundForEsc" = false;
      "HideScrollbar" = false;
      "DisableFullscreenTransparency" = false;
      "SplitPaneDimmingAmount" = 0.4;
      "EnableProxyIcon" = true;
      "EnableRendezvous" = false;
      "HideMenuBarInFullscreen" = true;
      "SUEnableAutomaticChecks" = true;
      "DisableWindowSizeSnap" = false;
      "TabStyleWithAutomaticOption" = 5;
      "TabViewType" = 0;
      "HideTab" = false;
      "ShowFullScreenTabBar" = true;
      "ShowPaneTitles" = true;
      "HideTabNumber" = false;
      "HideTabCloseButton" = false;
      "FlashTabBarInFullscreen" = true;
      "StretchTabsToFillBar" = true;
      "WindowStyle" = 0;
      "InitialWindowSize" = {
        Width = 1200;
        Height = 800;
      };
      "OpenNewWindowsHere" = true;
      "QuitWhenAllWindowsClosed" = false;
      "PromptOnQuit" = false;
      "ThemeFollowsSystemAppearance" = true;
      "DisableMetalWhenUnplugged" = false;
      "UseMetal" = true;
      "MetalMaximumFramesPerSecond" = 60;
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
