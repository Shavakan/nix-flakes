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

    # Check if SSH agent has keys loaded
    SSH_READY=true
    if ! /usr/bin/ssh-add -l >/dev/null 2>&1; then
      SSH_READY=false
      echo ""
      echo "SSH agent has no keys loaded. Marketplace operations will be skipped."
      echo "To enable marketplace plugins, run: ssh-add ~/.ssh/id_ed25519"
      echo "Then re-run: make home"
      echo ""
    fi

    INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
    TIMEOUT="${pkgs.coreutils}/bin/timeout"

    # Marketplace add operations require SSH for git clone
    if [ "$SSH_READY" = true ]; then
      if ! $TIMEOUT 5s ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "anthropics/skills"; then
        $DRY_RUN_CMD $TIMEOUT 10s ${pkgs.claude-code}/bin/claude plugin marketplace add anthropics/skills >/dev/null 2>&1 || true
      fi
      if ! $TIMEOUT 5s ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "Shavakan/claude-marketplace"; then
        $DRY_RUN_CMD $TIMEOUT 10s ${pkgs.claude-code}/bin/claude plugin marketplace add Shavakan/claude-marketplace >/dev/null 2>&1 || true
      fi
      if ! $TIMEOUT 5s ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "perplexityai/modelcontextprotocol"; then
        $DRY_RUN_CMD $TIMEOUT 10s ${pkgs.claude-code}/bin/claude plugin marketplace add perplexityai/modelcontextprotocol >/dev/null 2>&1 || true
      fi
      if ! $TIMEOUT 5s ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "anthropics/claude-code"; then
        $DRY_RUN_CMD $TIMEOUT 10s ${pkgs.claude-code}/bin/claude plugin marketplace add anthropics/claude-code >/dev/null 2>&1 || true
      fi
      if ! $TIMEOUT 5s ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "anthropics/claude-plugins-official"; then
        $DRY_RUN_CMD $TIMEOUT 10s ${pkgs.claude-code}/bin/claude plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1 || true
      fi
      if ! $TIMEOUT 5s ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "rami-code-review/claude-code-marketplace"; then
        $DRY_RUN_CMD $TIMEOUT 10s ${pkgs.claude-code}/bin/claude plugin marketplace add rami-code-review/claude-code-marketplace >/dev/null 2>&1 || true
      fi
    fi

    # Plugin installs work from local marketplace clones
    if ! grep -q "document-skills@anthropic-agent-skills" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install document-skills@anthropic-agent-skills >/dev/null 2>&1 || true
    fi
    if ! grep -q "example-skills@anthropic-agent-skills" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install example-skills@anthropic-agent-skills >/dev/null 2>&1 || true
    fi
    if ! grep -q "shavakan-skills@shavakan" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install shavakan-skills@shavakan >/dev/null 2>&1 || true
    fi
    if ! grep -q "shavakan-hooks@shavakan" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install shavakan-hooks@shavakan >/dev/null 2>&1 || true
    fi
    if ! grep -q "shavakan-commands@shavakan" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install shavakan-commands@shavakan >/dev/null 2>&1 || true
    fi
    if ! grep -q "shavakan-agents@shavakan" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install shavakan-agents@shavakan >/dev/null 2>&1 || true
    fi
    if ! grep -q "perplexity@perplexity-mcp-server" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install perplexity >/dev/null 2>&1 || true
    fi
    if ! grep -q "frontend-design@claude-code-plugins" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install frontend-design@claude-code-plugins >/dev/null 2>&1 || true
    fi
    if ! grep -q "playwright@claude-plugins-official" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install playwright@claude-plugins-official >/dev/null 2>&1 || true
    fi
    if ! grep -q "rami@rami-code-review" "$INSTALLED_PLUGINS" 2>/dev/null; then
      $DRY_RUN_CMD $TIMEOUT 30s ${pkgs.claude-code}/bin/claude plugin install rami@rami-code-review >/dev/null 2>&1 || true
    fi
  '';
}
