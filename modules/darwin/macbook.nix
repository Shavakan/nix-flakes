# MacBook-specific darwin configuration
{ pkgs, config, lib, ... }:

{
  # Set system hostname
  networking.hostName = "MacBook-changwonlee";
  
  # MacBook-specific packages
  environment.systemPackages = with pkgs; [ ];
}
