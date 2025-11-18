#!/bin/bash
set -euo pipefail

# Claude CI Fix Script
# This script is executed by Claude Code to automatically fix CI failures

FAILURE_LOG="/tmp/ci-failure.log"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
ATTEMPT=0

echo "=== Claude CI Auto-Fix ==="
echo "Run ID: $RUN_ID"
echo "Max attempts: $MAX_ATTEMPTS"
echo ""

# Safety check: ensure we're not on main/master
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" == "main" ]] || [[ "$CURRENT_BRANCH" == "master" ]]; then
  echo "ERROR: Refusing to run on main/master branch"
  exit 1
fi

# Function to check if we should continue
should_continue() {
  ATTEMPT=$((ATTEMPT + 1))

  if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    echo "ERROR: Exceeded max attempts ($MAX_ATTEMPTS)"
    echo "Manual intervention required"
    return 1
  fi

  echo "Attempt $ATTEMPT of $MAX_ATTEMPTS"
  return 0
}

# Main fix loop
while should_continue; do
  echo ""
  echo "--- Attempt $ATTEMPT ---"

  # Run Claude to analyze and fix
  claude-code <<'PROMPT'
<role>Nix build expert fixing CI failures. Analyze logs, apply minimal fixes, validate.</role>

<exit_protocol>
CRITICAL - Control script flow with exit codes:
- exit 0: Fixed and validated successfully
- exit 1: Cannot fix, need human intervention
- exit 2: Need retry with different approach
</exit_protocol>

<context>
Environment: Nix flakes home-manager configuration on feature branch
Failure logs: /tmp/ci-failure.log (use Read tool)
Working directory: Repository root
</context>

<task>
1. Read /tmp/ci-failure.log
2. Identify root cause (package test failure? dependency conflict? platform issue?)
3. Apply ONE of these fix patterns:

<nix_patterns>
Package test failures:
  Location: home.nix > nixpkgs.config.packageOverrides
  Example: fish.overrideAttrs (old: { doCheck = false; })

Dependency conflicts:
  Check: flake.lock versions
  Fix: nix flake update <input-name>

Platform issues:
  Replace: pkgs.system
  With: pkgs.stdenv.hostPlatform.system

VSCode extensions:
  Try sources: nixpkgs → vscode-marketplace → open-vsx
  Clear cache: nix-collect-garbage -d
</nix_patterns>

4. Validate:
   nix flake check && home-manager build --flake . --impure

5. Commit ONCE after validation passes:
   git status && git diff
   git add <changed-files>
   git commit -m "<technical-change-description>"

<commit_format>
Good (describes code change):
  "disable fish tests to resolve direnv build failures"
  "override readline to skip broken ncurses check"
  "replace deprecated pkgs.system with pkgs.stdenv.hostPlatform.system"

Bad (milestone/progress language):
  "fix CI" | "fix build errors" | "implement feature"

Rules:
- Message only, no footers/attribution
- Focus on WHAT changed in code, not project progress
- One commit per fix attempt
</commit_format>
</task>

<safety>
NEVER: commit secrets, refactor unrelated code, force-push
ONLY: fix the logged failure
IF_UNSURE: document issue in commit message, then exit 1
</safety>
PROMPT

  EXIT_CODE=$?

  # Check Claude's exit code
  case $EXIT_CODE in
    0)
      echo "✓ Claude reported success"

      # Verify there are commits
      if ! git diff --quiet origin/main; then
        echo "✓ Changes detected, validating..."

        # Run validation
        if nix flake check; then
          echo "✓ Flake check passed"

          if home-manager build --flake . --impure; then
            echo "✓ Home-manager build passed"
            echo ""
            echo "=== SUCCESS ==="
            echo "All fixes applied and validated"
            exit 0
          else
            echo "✗ Home-manager build failed, will retry..."
            continue
          fi
        else
          echo "✗ Flake check failed, will retry..."
          continue
        fi
      else
        echo "✗ No changes made by Claude"
        exit 1
      fi
      ;;

    1)
      echo "✗ Claude unable to fix, manual intervention needed"
      exit 1
      ;;

    2)
      echo "⟳ Claude requests retry"
      continue
      ;;

    *)
      echo "✗ Unexpected exit code: $EXIT_CODE"
      exit 1
      ;;
  esac
done

# If we get here, we exceeded max attempts
echo ""
echo "=== FAILED ==="
echo "Could not fix CI issues after $MAX_ATTEMPTS attempts"
echo "Manual review required"
exit 1
