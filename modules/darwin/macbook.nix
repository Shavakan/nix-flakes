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
        # Swap Command and Option/Alt keys on Realforce keyboard
        "0" = {
          "HIDKeyboardModifierMappingSrc" = 30064771072; # Command key
          "HIDKeyboardModifierMappingDst" = 30064771078; # Option/Alt key
        };
        "1" = {
          "HIDKeyboardModifierMappingSrc" = 30064771078; # Option/Alt key  
          "HIDKeyboardModifierMappingDst" = 30064771072; # Command key
        };
        # Swap Control and Caps Lock on Realforce keyboard
        "2" = {
          "HIDKeyboardModifierMappingSrc" = 30064771296; # Left Control
          "HIDKeyboardModifierMappingDst" = 30064771129; # Caps Lock
        };
        "3" = {
          "HIDKeyboardModifierMappingSrc" = 30064771129; # Caps Lock
          "HIDKeyboardModifierMappingDst" = 30064771296; # Left Control  
        };
      };
    };
  };

  # MacBook-specific LaunchAgents
  launchd.user.agents = {
    # MacBook-specific LaunchAgents can go here
  };
}
