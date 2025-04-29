# code.nix - Configuration for Claude Code terminal assistant
{ config, lib, pkgs, ... }:

{
  # Install Claude Code - AI coding assistant
  home.packages = [
    pkgs.claude-code
  ];

  # Set environment variables for Claude Code
  home.sessionVariables = {
    # Enable MCP support for Claude Code
    CLAUDE_CODE_MCP_ENABLED = "true";

    # Define allowed paths for filesystem access
    CLAUDE_CODE_ALLOWED_PATHS = "/Users/shavakan/Desktop:/Users/shavakan/Downloads:/Users/shavakan/workspace:/Users/shavakan/dotfiles:/Users/shavakan/nix-flakes";
  };
}
