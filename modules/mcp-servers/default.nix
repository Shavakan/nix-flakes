{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mcp-servers;

  # Helper function to get mode-specific environment variables
  getModeEnv = server: mode:
    server.environments.${mode} or (server.environments.default or { });

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

  };

  config = mkIf cfg.enable {
    # Claude Desktop configuration
    home.file."Library/Application Support/Claude/claude_desktop_config.json" = mkIf (cfg.servers != { }) {
      text = builtins.toJSON {
        mcpServers = mapAttrs
          (name: server: {
            command = "/bin/sh";
            args = [ "-c" "CURRENT_MODE=\${CURRENT_MODE:-devsisters}; PATH=/run/current-system/sw/bin:\$PATH; exec ${server.command} ${concatStringsSep " " server.args}" ];
            env = server.environments.devsisters or (server.environments.default or { });
          })
          (getServersForClient "claude-desktop");
      };
    };

    # Activation script to merge MCP settings with existing Claude settings
    home.activation.mergeClaudeSettings = lib.hm.dag.entryAfter [ "linkMountConfigurations" "installClaudePlugins" ] ''
      # Only proceed if MCP servers are enabled
      if [ "${if cfg.enable then "true" else "false"}" = "true" ] && [ ${toString (length (attrNames cfg.servers))} -gt 0 ]; then
        CLAUDE_SETTINGS="$HOME/.claude/settings.json"

        # Wait for rclone mount and plugin installation to complete (up to 15 seconds)
        for i in {1..15}; do
          if [ -f "$CLAUDE_SETTINGS" ]; then
            break
          fi
          sleep 1
        done

        if [ -f "$CLAUDE_SETTINGS" ]; then
          # Additional small delay to ensure plugin installation writes are complete
          sleep 2

          # Read existing settings
          EXISTING_SETTINGS=$(cat "$CLAUDE_SETTINGS")

          # Validate JSON before processing
          if command -v jq >/dev/null 2>&1; then
            if echo "$EXISTING_SETTINGS" | jq empty 2>/dev/null; then
              # Use jq to merge settings, preserving existing content
              MERGED_SETTINGS=$(echo "$EXISTING_SETTINGS" | jq '. + {
                "enableAllProjectMcpServers": true
              }')

              # Atomic write: write to temp file, then move
              TEMP_FILE=$(mktemp)
              echo "$MERGED_SETTINGS" > "$TEMP_FILE"

              # Verify the temp file is valid JSON before replacing
              if jq empty < "$TEMP_FILE" 2>/dev/null; then
                mv -f "$TEMP_FILE" "$CLAUDE_SETTINGS"

                if [ -n "$NIX_LOG_DIR" ]; then
                  log_nix "mcp-servers" "Merged MCP settings with existing Claude settings"
                fi
              else
                rm -f "$TEMP_FILE"
                if [ -n "$NIX_LOG_DIR" ]; then
                  log_nix "mcp-servers" "Failed to create valid merged settings, skipping"
                fi
              fi
            else
              if [ -n "$NIX_LOG_DIR" ]; then
                log_nix "mcp-servers" "Existing settings.json is invalid JSON, skipping merge to preserve file"
              fi
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
            command = "/bin/sh";
            args = [ "-c" "CURRENT_MODE=\${CURRENT_MODE:-devsisters}; PATH=/run/current-system/sw/bin:\$PATH; exec ${server.command} ${concatStringsSep " " server.args}" ];
            env = server.environments.devsisters or (server.environments.default or { });
          })
          (getServersForClient "gemini-cli");
      };
    };

  };
}
