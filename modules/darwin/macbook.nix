# MacBook-specific darwin configuration
{ pkgs, config, lib, ... }:

{
  # Set system hostname
  networking.hostName = "MacBook-changwonlee";
  
  # Any MacBook-specific packages
  environment.systemPackages = with pkgs; [
    # Add any MacBook-specific packages here
  ];
}
