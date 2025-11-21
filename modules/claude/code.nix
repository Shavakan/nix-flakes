# code.nix - Configuration for Claude Code terminal assistant
{ config, lib, pkgs, ... }:

{
  home.packages = [
    pkgs.claude-code
  ];

  home.sessionVariables = {
    CLAUDE_CODE_MCP_ENABLED = "true";
    CLAUDE_CODE_ALLOWED_PATHS = "/Users/shavakan/Desktop:/Users/shavakan/Downloads:/Users/shavakan/workspace:/Users/shavakan/dotfiles:/Users/shavakan/nix-flakes";
  };

  home.activation.installClaudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-$(launchctl getenv SSH_AUTH_SOCK 2>/dev/null || echo "")}"

    INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

    if ! ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "anthropics/skills"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin marketplace add anthropics/skills >/dev/null 2>&1 || true
    fi
    if ! grep -q "document-skills@anthropic-agent-skills" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install document-skills@anthropic-agent-skills >/dev/null 2>&1 || true
    fi
    if ! grep -q "example-skills@anthropic-agent-skills" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install example-skills@anthropic-agent-skills >/dev/null 2>&1 || true
    fi

    if ! ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "Shavakan/claude-marketplace"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin marketplace add Shavakan/claude-marketplace >/dev/null 2>&1 || true
    fi
    if ! grep -q "shavakan-skills@shavakan" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install shavakan-skills@shavakan >/dev/null 2>&1 || true
    fi
    if ! grep -q "shavakan-hooks@shavakan" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install shavakan-hooks@shavakan >/dev/null 2>&1 || true
    fi
    if ! grep -q "shavakan-commands@shavakan" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install shavakan-commands@shavakan >/dev/null 2>&1 || true
    fi
    if ! grep -q "shavakan-agents@shavakan" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install shavakan-agents@shavakan >/dev/null 2>&1 || true
    fi

    if ! ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "perplexityai/modelcontextprotocol"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin marketplace add perplexityai/modelcontextprotocol >/dev/null 2>&1 || true
    fi
    if ! grep -q "perplexity@perplexity-mcp-server" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install perplexity >/dev/null 2>&1 || true
    fi
  '';
}
