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
    # External keyboard configuration for MacBook only
    CustomUserPreferences = {
      # REALFORCE HYBRID US TKL keyboard mapping (VendorID: 2131, ProductID: 771)
      "com.apple.keyboard.modifiermapping.2131-771-0" = {
        # Swap Left Command and Left Alt
        "0" = {
          HIDKeyboardModifierMappingSrc = 30064771299; # Left Command
          HIDKeyboardModifierMappingDst = 30064771298; # Left Alt
        };
        "1" = {
          HIDKeyboardModifierMappingSrc = 30064771298; # Left Alt
          HIDKeyboardModifierMappingDst = 30064771299; # Left Command
        };
        # Swap Right Command and Right Alt
        "2" = {
          HIDKeyboardModifierMappingSrc = 30064771303; # Right Command
          HIDKeyboardModifierMappingDst = 30064771302; # Right Alt
        };
        "3" = {
          HIDKeyboardModifierMappingSrc = 30064771302; # Right Alt
          HIDKeyboardModifierMappingDst = 30064771303; # Right Command
        };
        # Swap Left Control and Caps Lock
        "4" = {
          HIDKeyboardModifierMappingSrc = 30064771296; # Left Control
          HIDKeyboardModifierMappingDst = 30064771129; # Caps Lock
        };
        "5" = {
          HIDKeyboardModifierMappingSrc = 30064771129; # Caps Lock
          HIDKeyboardModifierMappingDst = 30064771296; # Left Control
        };
      };
    };
  };

  # MacBook-specific LaunchAgents
  launchd.user.agents = {
    # MacBook-specific LaunchAgents can go here
  };
}
