{ config, pkgs, lib, ... }:

let
  # Define paths that should be accessible to Claude
  claudeAccessiblePaths = [
    "/Users/shavakan/Desktop"
    "/Users/shavakan/Downloads"
    "/Users/shavakan/workspace/svn2git"
    "/Users/shavakan/workspace/awsctx"
    "/Users/shavakan/workspace/cos-server"
    "/Users/shavakan/workspace/helm-charts-cos"
    "/Users/shavakan/dotfiles"
    "/Users/shavakan/nix-flakes"
    "/tmp"
  ];

  # Create wrapper scripts for MCP servers
  mcp-filesystem-wrapper = pkgs.writeShellScriptBin "mcp-filesystem-wrapper" ''
    #!/bin/bash
    # Set up the environment with the system-wide Node.js
    export PATH="/run/current-system/sw/bin:$PATH"
    # Execute the MCP filesystem server
    exec /run/current-system/sw/bin/npx @modelcontextprotocol/server-filesystem "$@"
  '';
  
  mcp-nixos-wrapper = pkgs.writeShellScriptBin "mcp-nixos-wrapper" ''
    #!/bin/bash
    # Set up the environment
    export PATH="/run/current-system/sw/bin:$PATH"
    # Execute the MCP NixOS server
    exec /run/current-system/sw/bin/uvx mcp-nixos
  '';
in
{
  # Install the wrapper scripts
  home.packages = [
    mcp-filesystem-wrapper
    mcp-nixos-wrapper
  ];
  
  # Create the MCP configuration file
  home.file.".claude-mcp-config.json".text = builtins.toJSON {
    mcpServers = {
      filesystem = {
        command = "${mcp-filesystem-wrapper}/bin/mcp-filesystem-wrapper";
        args = claudeAccessiblePaths;
      };
      nixos = {
        command = "${mcp-nixos-wrapper}/bin/mcp-nixos-wrapper";
        args = [];
      };
    };
  };
  
  # Set the MCP config environment variable globally
  home.sessionVariables = {
    CLAUDE_MCP_CONFIG = "${config.home.homeDirectory}/.claude-mcp-config.json";
  };
}
