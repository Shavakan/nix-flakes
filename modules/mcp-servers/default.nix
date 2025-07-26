{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mcp-servers;

  # Helper function to get mode-specific environment variables
  getModeEnv = server: mode:
    if server.environments ? ${mode} then
      server.environments.${mode}
    else
      server.environments.default or { };

  # Create wrapper script derivation for an MCP server
  mkMcpWrapper = name: server: pkgs.writeShellScriptBin "${name}-mcp-wrapper" ''
    #!/bin/bash
    # MCP Server: ${name}
    # Description: ${server.description}

    # Set up environment based on current mode
    CURRENT_MODE=''${CURRENT_MODE:-"devsisters"}

    # Default environment variables
    ${concatStringsSep "\n" (mapAttrsToList (key: value: 
      "export ${key}=\"${value}\""
    ) (server.environments.default or {}))}

    # Mode-specific environment variables
    case "$CURRENT_MODE" in
      personal)
        ${concatStringsSep "\n" (mapAttrsToList (key: value: 
          "export ${key}=\"${value}\""
        ) (server.environments.personal or {}))}
        ;;
      devsisters)
        ${concatStringsSep "\n" (mapAttrsToList (key: value: 
          "export ${key}=\"${value}\""
        ) (server.environments.devsisters or {}))}
        ;;
    esac

    # Execute the MCP server
    exec ${server.command} ${concatStringsSep " " server.args}
  '';

  # Create all MCP wrapper scripts
  mcpWrappers = mapAttrs mkMcpWrapper cfg.servers;

  # MCP management CLI tool
  mcpManager = pkgs.writeShellScriptBin "mcp" ''
    #!/bin/bash
    
    # MCP Server Management CLI
    case "$1" in
      list)
        echo "🔌 Available MCP Servers:"
        ${concatStringsSep "\n" (mapAttrsToList (name: server: ''
          echo "  ${name}: ${server.description}"
          echo "    Clients: ${concatStringsSep ", " server.clients}"
          echo "    Wrapper: ${mcpWrappers.${name}}/bin/${name}-mcp-wrapper"
          echo ""
        '') cfg.servers)}
        ;;
      status)
        echo "📊 MCP Server Status (Mode: ''${CURRENT_MODE:-devsisters}):"
        # Show running MCP processes
        ps aux | grep -E "(mcp|${concatStringsSep "|" (attrNames cfg.servers)})" | grep -v grep || echo "  No MCP servers currently running"
        ;;
      test)
        if [ -z "$2" ]; then
          echo "Usage: mcp test <server_name>"
          exit 1
        fi
        server_name="$2"
        case "$server_name" in
          ${concatStringsSep "\n          " (mapAttrsToList (name: server: ''
            ${name})
              echo "🧪 Testing MCP server: ${name}"
              echo "Wrapper: ${mcpWrappers.${name}}/bin/${name}-mcp-wrapper"
              echo "Description: ${server.description}"
              if [ -x "${mcpWrappers.${name}}/bin/${name}-mcp-wrapper" ]; then
                echo "✓ Wrapper script is executable"
              else
                echo "❌ Wrapper script is not executable"
              fi
              ;;''
          ) cfg.servers)}
          *)
            echo "❌ Unknown MCP server: $server_name"
            echo "Available servers: ${concatStringsSep ", " (attrNames cfg.servers)}"
            exit 1
            ;;
        esac
        ;;
      *)
        echo "🔌 MCP Server Management"
        echo ""
        echo "Commands:"
        echo "  mcp list         - List all available MCP servers"
        echo "  mcp status       - Show running MCP servers"
        echo "  mcp test <server> - Test a specific MCP server"
        echo ""
        echo "Current mode: ''${CURRENT_MODE:-devsisters}"
        echo "Available servers: ${concatStringsSep ", " (attrNames cfg.servers)}"
        ;;
    esac
  '';

  # Filter servers available for a specific client
  getServersForClient = client:
    filterAttrs
      (name: server:
        server.enable && elem client server.clients
      )
      cfg.servers;
in
{
  options.services.mcp-servers = {
    enable = mkEnableOption "unified MCP server management";

    servers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable this MCP server";
          };

          command = mkOption {
            type = types.str;
            description = "Command to start the MCP server";
          };

          args = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Arguments for the MCP server command";
          };

          clients = mkOption {
            type = types.listOf (types.enum [ "claude-code" "claude-desktop" "gemini-cli" ]);
            default = [ "claude-code" "claude-desktop" "gemini-cli" ];
            description = "Which AI clients should have access to this server";
          };

          environments = mkOption {
            type = types.attrsOf (types.attrsOf types.str);
            default = { };
            description = "Environment variables for different modes (personal, devsisters, default)";
            example = {
              personal = {
                API_KEY = "$PERSONAL_API_KEY";
                BASE_URL = "https://personal.example.com";
              };
              devsisters = {
                API_KEY = "$WORK_API_KEY";
                BASE_URL = "https://work.example.com";
              };
              default = {
                API_KEY = "$DEFAULT_API_KEY";
              };
            };
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Description of what this MCP server provides";
          };
        };
      });
      default = { };
      description = "MCP server configurations";
    };

    # Wrapper script directory
    wrapperDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.local/share/mcp-servers";
      description = "Directory to store MCP server wrapper scripts";
    };
  };

  config = mkIf cfg.enable {
    # Install the MCP management CLI tool
    home.packages = [ mcpManager ] ++ (attrValues mcpWrappers);

    # Claude Desktop configuration
    home.file."Library/Application Support/Claude/claude_desktop_config.json" = mkIf (cfg.servers != { }) {
      text = builtins.toJSON {
        mcpServers = mapAttrs
          (name: server: {
            command = "${mcpWrappers.${name}}/bin/${name}-mcp-wrapper";
            args = [ ];
          })
          (getServersForClient "claude-desktop");
      };
    };

    # Activation script to merge MCP settings with existing Claude settings
    home.activation.mergeClaudeSettings = lib.hm.dag.entryAfter [ "linkMountConfigurations" ] ''
      # Only proceed if MCP servers are enabled
      if [ "${if cfg.enable then "true" else "false"}" = "true" ] && [ ${toString (length (attrNames cfg.servers))} -gt 0 ]; then
        CLAUDE_SETTINGS="$HOME/.claude/settings.json"
        
        # Wait for rclone mount to be available (up to 10 seconds)
        for i in {1..10}; do
          if [ -f "$CLAUDE_SETTINGS" ]; then
            break
          fi
          sleep 1
        done
        
        if [ -f "$CLAUDE_SETTINGS" ]; then
          # Read existing settings
          EXISTING_SETTINGS=$(cat "$CLAUDE_SETTINGS")
          
          # Create merged settings with jq
          if command -v jq >/dev/null 2>&1; then
            # Use jq to merge settings, preserving existing content
            MERGED_SETTINGS=$(echo "$EXISTING_SETTINGS" | jq '. + {
              "enableAllProjectMcpServers": true
            }')
            
            # Write merged settings back
            echo "$MERGED_SETTINGS" > "$CLAUDE_SETTINGS"
            
            if [ -n "$NIX_LOG_DIR" ]; then
              log_nix "mcp-servers" "Merged MCP settings with existing Claude settings"
            fi
          else
            if [ -n "$NIX_LOG_DIR" ]; then
              log_nix "mcp-servers" "jq not available, skipping Claude settings merge"
            fi
          fi
        else
          if [ -n "$NIX_LOG_DIR" ]; then
            log_nix "mcp-servers" "Claude settings file not found, skipping merge"
          fi
        fi
      fi
    '';


    # Claude Code environment variables (only the documented ones)
    home.sessionVariables = mkIf (cfg.servers != { }) {
      # Set reasonable timeouts for MCP servers
      MCP_TIMEOUT = "10000"; # 10 seconds for server startup
      MCP_TOOL_TIMEOUT = "30000"; # 30 seconds for tool execution
      MAX_MCP_OUTPUT_TOKENS = "4096"; # Reasonable token limit
    };

    # Gemini CLI configuration
    home.file.".config/gemini-cli/settings.json" = mkIf (cfg.servers != { }) {
      text = builtins.toJSON {
        mcpServers = mapAttrs
          (name: server: {
            command = "${mcpWrappers.${name}}/bin/${name}-mcp-wrapper";
            args = [ ];
          })
          (getServersForClient "gemini-cli");
      };
    };

  };
}
