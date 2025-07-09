# MacBook-specific darwin configuration
{ pkgs, config, lib, ... }:

{
  # MacBook-specific packages
  environment.systemPackages = with pkgs; [ ];

  # MacBook-specific system settings
  system.defaults = {
    # MacBook-specific defaults
    dock = {
      autohide = true;
    };
  };

  # External keyboard configuration for MacBook only
  # REALFORCE HYBRID US TKL keyboard mapping
  system.keyboard = {
    enableKeyMapping = true;
    userKeyMapping = [
      # Swap Left Command and Left Alt
      {
        HIDKeyboardModifierMappingSrc = 30064771299; # Left Command
        HIDKeyboardModifierMappingDst = 30064771298; # Left Alt
      }
      {
        HIDKeyboardModifierMappingSrc = 30064771298; # Left Alt
        HIDKeyboardModifierMappingDst = 30064771299; # Left Command
      }
      # Swap Right Command and Right Alt
      {
        HIDKeyboardModifierMappingSrc = 30064771303; # Right Command
        HIDKeyboardModifierMappingDst = 30064771302; # Right Alt
      }
      {
        HIDKeyboardModifierMappingSrc = 30064771302; # Right Alt
        HIDKeyboardModifierMappingDst = 30064771303; # Right Command
      }
      # Swap Left Control and Caps Lock
      {
        HIDKeyboardModifierMappingSrc = 30064771296; # Left Control
        HIDKeyboardModifierMappingDst = 30064771129; # Caps Lock
      }
      {
        HIDKeyboardModifierMappingSrc = 30064771129; # Caps Lock
        HIDKeyboardModifierMappingDst = 30064771296; # Left Control
      }
    ];
  };

  # MacBook-specific LaunchAgents
  launchd.user.agents = {
    # MacBook-specific LaunchAgents can go here
  };
}
