# Mac Studio-specific darwin configuration
{ pkgs, config, lib, ... }:

{
  # Set system hostname
  networking.hostName = "macstudio-changwonlee";
  
  # Mac Studio-specific system packages
  environment.systemPackages = with pkgs; [
    # Add any Mac Studio-specific packages here
    # For example, additional development tools
    jetbrains.clion
    jetbrains.datagrip
  ];
}
