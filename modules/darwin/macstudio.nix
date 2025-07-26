# Mac Studio-specific darwin configuration
{ pkgs, config, lib, ... }:

{
  # Mac Studio-specific system packages
  environment.systemPackages = with pkgs; [ ];

  # Mac Studio-specific system settings
  system.defaults = {
    # Mac Studio-specific defaults
    dock = {
      autohide = true;
      # Different Dock settings for desktop Mac
      magnification = true;
    };

    # Trackpad settings specific to this machine
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true; # Enable three-finger drag
    };

    # Power management settings to help with USB devices after wake
    CustomUserPreferences = {
      # System-wide power management settings
      "com.apple.PowerManagement" = {
        "SleepDisabled" = false;
        "hibernatemode" = 0; # Disable hibernation (0 = no hibernate)
        "standby" = 0; # Disable standby
        "ttyskeepawake" = 1; # Prevent sleep while SSH sessions are active
        "acwake" = 1; # Wake on AC power reconnect
        "lidwake" = 1; # Wake when lid is opened

        # Don't power down USB controllers during sleep
        # This helps with device recognition after wake
        "IOPMEnableBluetoothWakeFromSleep" = 1; # Enable Bluetooth wake
        "UPSRestart" = 1; # Auto-restart after power loss
      };

      # USB power management settings
      "com.apple.driver.AppleUSBMergeNub" = {
        "IOClass" = "AppleUSBMergeNub";
        "IOProviderClass" = "AppleUSBDevice";
        "idProduct" = 0; # For all USB devices
        "idVendor" = 0; # For all USB vendors
        "IOPersonalityPublisher" = "com.apple.driver.AppleUSBMergeNub";
        # Prevent USB device suspension during sleep
        "kUSBSleepPortCurrentLimit" = 2100; # Increase sleep current limit to 2100mA
        "kUSBSleepPowerSupply" = 2100; # Increase sleep power supply to 2100mA
        "kUSBWakePortCurrentLimit" = 2100; # Increase wake current limit to 2100mA
        "kUSBWakePowerSupply" = 2100; # Increase wake power supply to 2100mA
      };

      # IOKit USB settings for HID devices (keyboard, mouse)
      "com.apple.iokit.IOUSBFamily" = {
        "USBHIDWakeForeverEnabled" = true; # Keep HID devices awake
        "USBHIDWakeSupport" = true; # Support wake from HID devices
        "USBHIDPostResumeDelay" = 1000; # Wait 1 second after resume before accepting HID input
        "USBHIDPowerManagement" = 0; # Disable HID power management to prevent sleep issues
      };

      # XHCI controller settings to prevent reset on wake
      "com.apple.driver.usb.AppleUSBXHCI" = {
        "IOCFPlugInTypes" = "";
        "IOPowerManagement" = {
          "CapabilityFlags" = 32768; # Keep device powered during sleep
          "CurrentPowerState" = 2; # Always on
          "DevicePowerState" = 2; # Always on
          "WakeReason" = 2; # Wake from any input
        };
      };

      # Additional trackpad gesture settings
      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
        # Customize page swiping
        "TrackpadTwoFingerFromRightEdgeSwipeGesture" = 0; # Disable two-finger swipe from edge

        # Set specific gesture mappings
        "TrackpadThreeFingerDrag" = true; # Enable three-finger drag
      };

      # Apply same settings to Magic Mouse
      "com.apple.driver.AppleBluetoothMultitouch.mouse" = {
        "MouseTwoFingerHorizSwipeGesture" = 1; # Enable two-finger swipe for page navigation
      };

      # Apple Watch unlock settings
      "com.apple.security.plist" = {
        "AutoUnlock" = true; # Enable Apple Watch unlock
      };

      # Apple Watch auto unlock settings
      "com.apple.autounlock" = {
        "enabled" = 1; # Enable Apple Watch Auto Unlock
        "disable-proximity-notifications" = 0; # Allow proximity notifications
        "ShouldNotifyActivity" = 1; # Notify user of unlock activity
        "DeviceIsSupportedForAutoUnlock" = 1; # Mark this Mac as supported
      };

      # Security & Privacy preferences to allow Apple Watch
      "com.apple.security" = {
        "AutoWake" = true; # Wake for network access
        "DisableLockOnSleep" = false; # Lock when sleeping
        "UseProximityMonitoring" = true; # Use Apple Watch for proximity monitoring
        "UWUPActive" = true; # Allow Apple Watch unlock
      };
    };
  };

  # Mac Studio-specific LaunchAgents
  launchd.user.agents = {
    # Mac Studio-specific LaunchAgents can go here
  };
}
