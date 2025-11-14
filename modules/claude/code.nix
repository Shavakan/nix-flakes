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
    # Ensure SSH agent is available for git operations
    export SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-$(launchctl getenv SSH_AUTH_SOCK 2>/dev/null || echo "")}"


    if ! ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "anthropics/skills"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin marketplace add anthropics/skills >/dev/null 2>&1 || true
    fi
    if ! ${pkgs.claude-code}/bin/claude plugin list 2>/dev/null | grep -q "document-skills@anthropic-agent-skills"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install document-skills@anthropic-agent-skills >/dev/null 2>&1 || true
    fi
    if ! ${pkgs.claude-code}/bin/claude plugin list 2>/dev/null | grep -q "example-skills@anthropic-agent-skills"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install example-skills@anthropic-agent-skills >/dev/null 2>&1 || true
    fi

    if ! ${pkgs.claude-code}/bin/claude plugin marketplace list 2>/dev/null | grep -q "Shavakan/claude-marketplace"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin marketplace add Shavakan/claude-marketplace >/dev/null 2>&1 || true
    fi
    if ! ${pkgs.claude-code}/bin/claude plugin list 2>/dev/null | grep -q "shavakan-skills@shavakan"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install shavakan-skills@shavakan >/dev/null 2>&1 || true
    fi
    if ! ${pkgs.claude-code}/bin/claude plugin list 2>/dev/null | grep -q "shavakan-hooks@shavakan"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install shavakan-hooks@shavakan >/dev/null 2>&1 || true
    fi
    if ! ${pkgs.claude-code}/bin/claude plugin list 2>/dev/null | grep -q "shavakan-commands@shavakan"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install shavakan-commands@shavakan >/dev/null 2>&1 || true
    fi
    if ! ${pkgs.claude-code}/bin/claude plugin list 2>/dev/null | grep -q "shavakan-agents@shavakan"; then
      $DRY_RUN_CMD ${pkgs.claude-code}/bin/claude plugin install shavakan-agents@shavakan >/dev/null 2>&1 || true
    fi
  '';
}
