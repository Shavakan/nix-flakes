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
  };

  # Mac Studio-specific LaunchAgents
  launchd.user.agents = {
    # Mac Studio-specific LaunchAgents can go here
  };
}
