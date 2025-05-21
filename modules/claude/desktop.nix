# desktop.nix - Configuration for Claude desktop application
{ config, lib, pkgs, ... }:

let
  # Define paths that should be accessible to Claude
  claudeAccessiblePaths = [
    "/Users/shavakan/Desktop"
    "/Users/shavakan/Downloads"
    "/Users/shavakan/nix-flakes"
  ];

  # File content for MCP filesystem wrapper
  fileSystemWrapperContent = ''
    #!/bin/bash
    # Set up the environment
    export PATH="/run/current-system/sw/bin:$PATH"
    # Execute the command
    exec /run/current-system/sw/bin/npx @modelcontextprotocol/server-filesystem "$@"
  '';

  # Claude desktop config (exactly matching existing working config)
  claudeDesktopConfig = {
    mcpServers = {
      filesystem = {
        command = "/Users/shavakan/Library/Application Support/Claude/mcp-filesystem-wrapper.sh";
        args = claudeAccessiblePaths;
      };
      nixos = {
        command = "/run/current-system/sw/bin/uvx";
        args = [
          "mcp-nixos"
        ];
      };
    };
  };
in
{
  # Create activation script to write the Claude desktop config file and wrapper script
  home.activation.configureClaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Ensure Claude directory exists with proper permissions
    CLAUDE_DIR="$HOME/Library/Application Support/Claude"
    $DRY_RUN_CMD mkdir -p "$CLAUDE_DIR"
    
    # Create the MCP filesystem wrapper script
    WRAPPER_PATH="$CLAUDE_DIR/mcp-filesystem-wrapper.sh"
    WRAPPER_CONTENT='${fileSystemWrapperContent}'
    
    # Write wrapper script to temporary file first to avoid partial writes
    TEMP_WRAPPER=$(mktemp)
    $DRY_RUN_CMD echo "$WRAPPER_CONTENT" > "$TEMP_WRAPPER"
    
    # Move temporary file to final location and make executable
    $DRY_RUN_CMD mv "$TEMP_WRAPPER" "$WRAPPER_PATH"
    $DRY_RUN_CMD chmod 755 "$WRAPPER_PATH"
    
    # Create the Claude desktop config file
    CONFIG_FILE="$CLAUDE_DIR/claude_desktop_config.json"
    CONFIG_CONTENT='${builtins.toJSON claudeDesktopConfig}'
    
    # Write config to temporary file first to avoid partial writes
    TEMP_CONFIG=$(mktemp)
    $DRY_RUN_CMD echo "$CONFIG_CONTENT" > "$TEMP_CONFIG"
    
    # Move temporary file to final location
    $DRY_RUN_CMD mv "$TEMP_CONFIG" "$CONFIG_FILE"
    $DRY_RUN_CMD chmod 600 "$CONFIG_FILE"
  '';
}
