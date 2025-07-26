# default.nix - Main entry point for Claude module
{ config, lib, pkgs, ... }:

{
  # Import both desktop and code configurations
  imports = [
    # Disabled old desktop.nix in favor of unified MCP server system
    # ./desktop.nix  # Claude desktop app configuration
    ./code.nix # Claude Code terminal assistant
  ];
}
