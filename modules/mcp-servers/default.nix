{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mcp-servers;

  # Helper function to get mode-specific environment variables
  getModeEnv = server: mode:
    server.environments.${mode} or (server.environments.default or { });

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

  # Enhanced MCP management CLI tool with profiles and project support
  mcpManager = pkgs.writeShellScriptBin "mcp" ''
    #!/bin/bash
    
    # Configuration paths
    PROFILES_DIR="$HOME/.config/mcp/profiles"
    PROJECT_CONFIG=".mcp-config"
    
    # Ensure profiles directory exists
    mkdir -p "$PROFILES_DIR"
    
    # Helper functions
    show_help() {
      echo "🔌 MCP Server Management"
      echo ""
      echo "Server Information:"
      echo "  mcp list                    - List enabled servers for this project"
      echo "  mcp list all                - List all available servers"
      echo ""
      echo "Project Management (current directory):"
      echo "  mcp enable <servers...>     - Enable servers for this project"
      echo "  mcp disable <servers...>    - Disable servers from this project"
      echo "  mcp current                 - Show active servers in this project"
      echo "  mcp status                  - Show project MCP status"
      echo ""
      echo "Profile Management (global):"
      echo "  mcp profile create <name>             - Create empty profile"
      echo "  mcp profile add <name> <servers...>   - Add servers to profile"
      echo "  mcp profile remove <name> <servers...> - Remove servers from profile"
      echo "  mcp profile list                      - Show all profiles"
      echo "  mcp profile show <name>               - Show servers in profile"
      echo ""
      echo "Legacy Commands:"
      echo "  mcp test <server>           - Test a specific server"
      echo ""
      echo "Available servers: ${concatStringsSep ", " (attrNames cfg.servers)}"
    }
    
    list_all_servers() {
      echo "🔌 Available MCP Servers:"
      echo ""
      ${concatStringsSep "\n" (mapAttrsToList (name: server: ''
        printf "  📦 %-20s %s\n" "${name}" "${server.description}"
      '') cfg.servers)}
    }
    
    list_project_servers() {
      local servers=$(get_project_servers)
      if [ -n "$servers" ]; then
        echo "🔌 Enabled MCP Servers (this project):"
        echo ""
        for server in $servers; do
          # Get description for this server
          case "$server" in
            ${concatStringsSep "\n            " (mapAttrsToList (name: server: ''
              ${name}) printf "  ✅ %-20s %s\n" "${name}" "${server.description}" ;;''
            ) cfg.servers)}
            *) printf "  ✅ %-20s %s\n" "$server" "(unknown server)" ;;
          esac
        done
      else
        echo "🔌 No MCP servers enabled for this project"
        echo ""
        echo "💡 Use 'mcp enable <server>' to enable servers"
        echo "💡 Use 'mcp list all' to see available servers"
      fi
    }
    
    get_project_servers() {
      if [ -f "$PROJECT_CONFIG" ]; then
        cat "$PROJECT_CONFIG" | tr '\n' ' '
      fi
    }
    
    generate_claude_config() {
      local servers="$1"
      local config="{\n  \"mcpServers\": {\n"
      local first=true
      
      for server in $servers; do
        if [ "$first" = true ]; then
          first=false
        else
          config="$config,\n"
        fi
        # Get wrapper path for this server
        case "$server" in
          ${concatStringsSep "\n          " (mapAttrsToList (name: wrapper: ''
            ${name}) wrapper_path="${wrapper}/bin/${name}-mcp-wrapper" ;;''
          ) mcpWrappers)}
          *) wrapper_path="unknown" ;;
        esac
        config="$config    \"$server\": {\n"
        config="$config      \"type\": \"stdio\",\n"
        config="$config      \"command\": \"$wrapper_path\",\n"
        config="$config      \"args\": [],\n"
        config="$config      \"env\": {}\n"
        config="$config    }"
      done
      
      config="$config\n  }\n}"
      echo -e "$config" > .mcp.json
    }
    
    generate_gemini_config() {
      local servers="$1"
      local config="{\n  \"mcpServers\": {\n"
      local first=true
      
      for server in $servers; do
        if [ "$first" = true ]; then
          first=false
        else
          config="$config,\n"
        fi
        # Get wrapper path for this server
        case "$server" in
          ${concatStringsSep "\n          " (mapAttrsToList (name: wrapper: ''
            ${name}) wrapper_path="${wrapper}/bin/${name}-mcp-wrapper" ;;''
          ) mcpWrappers)}
          *) wrapper_path="unknown" ;;
        esac
        config="$config    \"$server\": {\n"
        config="$config      \"type\": \"stdio\",\n"
        config="$config      \"command\": \"$wrapper_path\",\n"
        config="$config      \"args\": [],\n"
        config="$config      \"env\": {}\n"
        config="$config    }"
      done
      
      config="$config\n  }\n}"
      echo -e "$config" > .gemini-mcp.json
    }
    
    update_project_configs() {
      local servers=$(get_project_servers)
      if [ -n "$servers" ]; then
        generate_claude_config "$servers"
        generate_gemini_config "$servers"
        echo "✓ Updated .mcp.json and .gemini-mcp.json"
      else
        rm -f .mcp.json .gemini-mcp.json
        echo "✓ Removed MCP configuration files"
      fi
    }
    
    # Main command handling
    case "$1" in
      list)
        if [ "$2" = "all" ]; then
          list_all_servers
        else
          list_project_servers
        fi
        ;;
        
      enable)
        if [ -z "$2" ]; then
          echo "Usage: mcp enable <server1> [server2] ..."
          exit 1
        fi
        shift
        current_servers=$(get_project_servers)
        for server in "$@"; do
          # Validate server exists
          case "$server" in
            ${concatStringsSep "|" (attrNames cfg.servers)})
              if ! echo "$current_servers" | grep -q "$server"; then
                echo "$server" >> "$PROJECT_CONFIG"
                echo "✓ Enabled $server for this project"
              else
                echo "⚠️  $server already enabled"
              fi
              ;;
            *)
              echo "❌ Unknown server: $server"
              echo "Available: ${concatStringsSep ", " (attrNames cfg.servers)}"
              ;;
          esac
        done
        update_project_configs
        ;;
        
      disable)
        if [ -z "$2" ]; then
          echo "Usage: mcp disable <server1> [server2] ..."
          exit 1
        fi
        if [ ! -f "$PROJECT_CONFIG" ]; then
          echo "No MCP servers enabled for this project"
          exit 0
        fi
        shift
        for server in "$@"; do
          if grep -q "^$server$" "$PROJECT_CONFIG"; then
            grep -v "^$server$" "$PROJECT_CONFIG" > "$PROJECT_CONFIG.tmp"
            mv "$PROJECT_CONFIG.tmp" "$PROJECT_CONFIG"
            echo "✓ Disabled $server for this project"
          else
            echo "⚠️  $server not enabled for this project"
          fi
        done
        # Clean up empty config file
        if [ ! -s "$PROJECT_CONFIG" ]; then
          rm -f "$PROJECT_CONFIG"
        fi
        update_project_configs
        ;;
        
      current)
        servers=$(get_project_servers)
        if [ -n "$servers" ]; then
          echo "📍 Active MCP servers for this project:"
          for server in $servers; do
            echo "  • $server"
          done
        else
          echo "No MCP servers enabled for this project"
        fi
        ;;
        
      status)
        echo "📊 Project MCP Status:"
        servers=$(get_project_servers)
        if [ -n "$servers" ]; then
          echo "Enabled servers: $servers"
          echo "Mode: ''${CURRENT_MODE:-devsisters}"
          if [ -f ".mcp.json" ]; then
            echo "✓ .mcp.json exists"
          fi
          if [ -f ".gemini-mcp.json" ]; then
            echo "✓ .gemini-mcp.json exists"
          fi
        else
          echo "No servers enabled for this project"
        fi
        ;;
        
      profile)
        case "$2" in
          create)
            if [ -z "$3" ]; then
              echo "Usage: mcp profile create <name>"
              exit 1
            fi
            profile_file="$PROFILES_DIR/$3"
            if [ -f "$profile_file" ]; then
              echo "❌ Profile '$3' already exists"
              exit 1
            fi
            touch "$profile_file"
            echo "✓ Created profile '$3'"
            ;;
            
          add)
            if [ -z "$3" ] || [ -z "$4" ]; then
              echo "Usage: mcp profile add <name> <server1> [server2] ..."
              exit 1
            fi
            profile_name="$3"
            profile_file="$PROFILES_DIR/$profile_name"
            if [ ! -f "$profile_file" ]; then
              echo "❌ Profile '$profile_name' doesn't exist. Create it first."
              exit 1
            fi
            shift 3
            for server in "$@"; do
              case "$server" in
                ${concatStringsSep "|" (attrNames cfg.servers)})
                  if ! grep -q "^$server$" "$profile_file"; then
                    echo "$server" >> "$profile_file"
                    echo "✓ Added $server to profile '$profile_name'"
                  else
                    echo "⚠️  $server already in profile '$profile_name'"
                  fi
                  ;;
                *)
                  echo "❌ Unknown server: $server"
                  ;;
              esac
            done
            ;;
            
          remove)
            if [ -z "$3" ] || [ -z "$4" ]; then
              echo "Usage: mcp profile remove <name> <server1> [server2] ..."
              exit 1
            fi
            profile_name="$3"
            profile_file="$PROFILES_DIR/$profile_name"
            if [ ! -f "$profile_file" ]; then
              echo "❌ Profile '$profile_name' doesn't exist"
              exit 1
            fi
            shift 3
            for server in "$@"; do
              if grep -q "^$server$" "$profile_file"; then
                grep -v "^$server$" "$profile_file" > "$profile_file.tmp"
                mv "$profile_file.tmp" "$profile_file"
                echo "✓ Removed $server from profile '$profile_name'"
              else
                echo "⚠️  $server not in profile '$profile_name'"
              fi
            done
            ;;
            
          list)
            echo "📋 Available Profiles:"
            if [ -d "$PROFILES_DIR" ] && [ "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]; then
              for profile in "$PROFILES_DIR"/*; do
                if [ -f "$profile" ]; then
                  name=$(basename "$profile")
                  count=$(wc -l < "$profile" 2>/dev/null || echo 0)
                  echo "  $name ($count servers)"
                fi
              done
            else
              echo "  No profiles created yet"
            fi
            ;;
            
          show)
            if [ -z "$3" ]; then
              echo "Usage: mcp profile show <name>"
              exit 1
            fi
            profile_file="$PROFILES_DIR/$3"
            if [ ! -f "$profile_file" ]; then
              echo "❌ Profile '$3' doesn't exist"
              exit 1
            fi
            echo "📋 Profile '$3':"
            if [ -s "$profile_file" ]; then
              while read -r server; do
                echo "  • $server"
              done < "$profile_file"
            else
              echo "  (empty)"
            fi
            ;;
            
          *)
            echo "Profile commands:"
            echo "  mcp profile create <name>             - Create empty profile"
            echo "  mcp profile add <name> <servers...>   - Add servers to profile"
            echo "  mcp profile remove <name> <servers...> - Remove servers from profile"
            echo "  mcp profile list                      - Show all profiles"
            echo "  mcp profile show <name>               - Show servers in profile"
            ;;
        esac
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
        show_help
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
