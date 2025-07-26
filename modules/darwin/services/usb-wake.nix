# modules/darwin/services/usb-wake.nix
# Service to reinitialize USB devices after wake from sleep
{ config, lib, pkgs, ... }:

let
  # Script to reset USB devices after wake
  resetUsbScript = pkgs.writeShellScript "reset-usb.sh" ''
    # Wait for system to fully wake up
    sleep 2
    
    # Reset USB controller by unloading and reloading the driver
    # This is a macOS-specific approach using kextunload/kextload
    /usr/sbin/kextunload -b com.apple.driver.usb.AppleUSBXHCI
    /usr/sbin/kextload -b com.apple.driver.usb.AppleUSBXHCI
    
    # Log the reset
    echo "USB controller reset at $(date)" >> /tmp/usb-reset.log
  '';
in
{
  # Define the launchd service for nix-darwin
  launchd.user.agents.resetUsbAfterWake = {
    serviceConfig = {
      Label = "com.user.resetUsbAfterWake";
      ProgramArguments = [ "${resetUsbScript}" ];
      RunAtLoad = false;
      StartOnMount = false;

      # Run when system wakes from sleep
      WatchPaths = [ "/Library/Preferences/SystemConfiguration/com.apple.PowerManagement.plist" ];
    };
  };
}
