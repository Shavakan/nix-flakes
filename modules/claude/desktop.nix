# desktop.nix - Configuration for Claude desktop application
{ config, lib, pkgs, ... }:

let
  # Define machine-specific configurations
  machineConfigs = {
    "macbook" = {
      # MacBook-specific accessible paths
      claudeAccessiblePaths = [
        "/Users/shavakan/Desktop"
        "/Users/shavakan/Downloads"
        "/Users/shavakan/nix-flakes"
        "/Users/shavakan/workspace/awsctx"
        "/Users/shavakan/workspace/cos-server"
        "/Users/shavakan/workspace/helm-charts-cos"
      ];
    };

    "macstudio" = {
      # Mac Studio-specific accessible paths
      claudeAccessiblePaths = [
        "/Users/shavakan/Desktop"
        "/Users/shavakan/Downloads"
        "/Users/shavakan/nix-flakes"
      ];
    };
  };

  # Default accessible paths (used if hostname detection fails)
  defaultAccessiblePaths = [
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

  # File content for MCP GitHub wrapper
  githubWrapperContent = ''
    #!/bin/bash
    # Set up the environment
    export PATH="/run/current-system/sw/bin:$PATH"
    
    # Check if GITHUB_PERSONAL_ACCESS_TOKEN is set
    if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
      echo "Error: GITHUB_PERSONAL_ACCESS_TOKEN environment variable is not set" >&2
      exit 1
    fi
    
    # Execute the GitHub MCP server in stdio mode
    exec /run/current-system/sw/bin/podman run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" ghcr.io/github/github-mcp-server stdio
  '';

  # File content for MCP Terraform wrapper
  terraformWrapperContent = ''
    #!/bin/bash
    # Set up the environment
    export PATH="/run/current-system/sw/bin:$PATH"
    
    # Execute the Terraform MCP server in stdio mode
    exec /run/current-system/sw/bin/podman run -i --rm hashicorp/terraform-mcp-server
  '';


  # Function to generate Claude desktop config based on paths
  mkClaudeDesktopConfig = paths: {
    mcpServers = {
      filesystem = {
        command = "/Users/shavakan/Library/Application Support/Claude/mcp-filesystem-wrapper.sh";
        args = paths;
      };
      nixos = {
        command = "/run/current-system/sw/bin/uvx";
        args = [
          "mcp-nixos"
        ];
      };
      github = {
        command = "/Users/shavakan/Library/Application Support/Claude/mcp-github-wrapper.sh";
        args = [ ];
      };
      terraform = {
        command = "/Users/shavakan/Library/Application Support/Claude/mcp-terraform-wrapper.sh";
        args = [ ];
      };
      notion = {
        transport = "http";
        url = "https://mcp.notion.com/mcp";
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
    
    # Create the MCP GitHub wrapper script
    GITHUB_WRAPPER_PATH="$CLAUDE_DIR/mcp-github-wrapper.sh"
    GITHUB_WRAPPER_CONTENT='${githubWrapperContent}'
    
    # Write GitHub wrapper script to temporary file first to avoid partial writes
    TEMP_GITHUB_WRAPPER=$(mktemp)
    $DRY_RUN_CMD echo "$GITHUB_WRAPPER_CONTENT" > "$TEMP_GITHUB_WRAPPER"
    
    # Move temporary file to final location and make executable
    $DRY_RUN_CMD mv "$TEMP_GITHUB_WRAPPER" "$GITHUB_WRAPPER_PATH"
    $DRY_RUN_CMD chmod 755 "$GITHUB_WRAPPER_PATH"
    
    # Create the MCP Terraform wrapper script
    TERRAFORM_WRAPPER_PATH="$CLAUDE_DIR/mcp-terraform-wrapper.sh"
    TERRAFORM_WRAPPER_CONTENT='${terraformWrapperContent}'
    
    # Write Terraform wrapper script to temporary file first to avoid partial writes
    TEMP_TERRAFORM_WRAPPER=$(mktemp)
    $DRY_RUN_CMD echo "$TERRAFORM_WRAPPER_CONTENT" > "$TEMP_TERRAFORM_WRAPPER"
    
    # Move temporary file to final location and make executable
    $DRY_RUN_CMD mv "$TEMP_TERRAFORM_WRAPPER" "$TERRAFORM_WRAPPER_PATH"
    $DRY_RUN_CMD chmod 755 "$TERRAFORM_WRAPPER_PATH"
    
    # Detect hostname and machine type to determine accessible paths
    if [ -x /bin/hostname ]; then
      HOSTNAME_CMD="/bin/hostname"
    elif [ -x /usr/bin/hostname ]; then
      HOSTNAME_CMD="/usr/bin/hostname"
    else
      CURRENT_HOSTNAME="unknown"
    fi

    if [ -n "$HOSTNAME_CMD" ]; then
      CURRENT_HOSTNAME=$($HOSTNAME_CMD | tr -d '\n')
    fi
    
    MACHINE_TYPE="unknown"
    CONFIG_CONTENT=""
    
    if [[ "$CURRENT_HOSTNAME" == MacBook* ]]; then
      MACHINE_TYPE="macbook"
      CONFIG_CONTENT='${builtins.toJSON (mkClaudeDesktopConfig machineConfigs.macbook.claudeAccessiblePaths)}'
    elif [[ "$CURRENT_HOSTNAME" == macstudio* ]]; then
      MACHINE_TYPE="macstudio"
      CONFIG_CONTENT='${builtins.toJSON (mkClaudeDesktopConfig machineConfigs.macstudio.claudeAccessiblePaths)}'
    else
      CONFIG_CONTENT='${builtins.toJSON (mkClaudeDesktopConfig defaultAccessiblePaths)}'
    fi
    
    # Create the Claude desktop config file
    CONFIG_FILE="$CLAUDE_DIR/claude_desktop_config.json"
    
    # Write config to temporary file first to avoid partial writes
    TEMP_CONFIG=$(mktemp)
    $DRY_RUN_CMD echo "$CONFIG_CONTENT" > "$TEMP_CONFIG"
    
    # Expand environment variables in the config file using envsubst
    if [ -n "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
      $DRY_RUN_CMD envsubst < "$TEMP_CONFIG" > "$TEMP_CONFIG.tmp"
      $DRY_RUN_CMD mv "$TEMP_CONFIG.tmp" "$TEMP_CONFIG"
    fi
    
    # Move temporary file to final location
    $DRY_RUN_CMD mv "$TEMP_CONFIG" "$CONFIG_FILE"
    $DRY_RUN_CMD chmod 600 "$CONFIG_FILE"
  '';
}
