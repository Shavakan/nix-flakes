# Mac Studio-specific darwin configuration
{ pkgs, config, lib, ... }:

{
  # Set system hostname
  networking.hostName = "macstudio-changwonlee";
  
  # Mac Studio-specific system packages
  environment.systemPackages = with pkgs; [ ];
}
