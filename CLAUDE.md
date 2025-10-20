# CLAUDE.md

This file provides guidance to Claude Code when working with this nix-flakes repository.

## Critical Constraints

**Long-running builds**: ALWAYS run `make home` and `make update` in background - they can take 5-10 minutes. Wait 10-15 seconds between BashOutput checks to avoid excessive polling.

**Complete before reporting**: When running multi-step operations (update → build → apply), wait for ALL steps to complete and verify success before reporting back to user. Do not provide interim updates to CLAUDE.md or other documentation until the entire workflow finishes successfully.

**Build testing**: NEVER apply without testing first. Always `home-manager build --flake . --impure` before `make home`.

**Impure flag required**: All home-manager and darwin-rebuild commands need `--impure` due to runtime machine detection.

## Skills (CHECK FIRST)

Before responding, check if task matches a skill in `.claude/skills/`:
- Package queries → `.claude/skills/nix-package-finder/SKILL.md`
- Build/apply commands → `.claude/skills/background-build-monitor/SKILL.md`
- VSCode extension issues → `.claude/skills/vscode-extension-resolver/SKILL.md`

Read matching skill's SKILL.md and follow its instructions exactly.

## Common Commands

```bash
# User config (BACKGROUND ONLY)
make home              # home-manager switch --flake . --impure
home-manager build --flake . --impure  # Test without applying

# System config
make darwin            # darwin-rebuild switch --flake .#$(hostname) --impure

# Updates (BACKGROUND ONLY)
make update            # nix flake update

# Cleanup
make clean             # nix-collect-garbage + optimize

# MCP management
mcp list              # Show enabled servers for project
mcp enable <servers>  # Enable servers (creates .mcp-config)
mcp status            # Show mode and active servers
```

## Architecture

**Dual configuration system:**
- `nix-darwin`: System-level macOS settings (`modules/darwin/`)
- `home-manager`: User-specific configs (`modules/*/`)
- Entry points: `flake.nix`, `home.nix`

**Module patterns:**
- Standard: `mkEnableOption` + `mkIf cfg.enable`
- Multi-file modules split by concern
- Activation scripts use DAG ordering: `lib.hm.dag.entryAfter ["dependency"]`
- Cross-module theme injection via `_module.args.selectedTheme`

**Theme system** (`modules/themes/`):
- Centralized color management for terminal, ls, git, completion
- Available: nord (default), monokai, solarized-dark, solarized-light
- Change via `themes.selected` in `home.nix`

**Host detection** (`modules/host-config/`):
- Runtime detection writes to `~/.nix-host-*` files
- Applies machine-specific settings (git signing keys, etc.)

**Services pattern** (see rclone):
- Modular imports for different aspects
- Activation scripts with DAG dependencies
- Comprehensive logging to `~/nix-flakes/logs/`
- State tracking via hash files

**Secrets**: agenix encrypts `modules/agenix/` files, decrypted during activation before dependent services start.

## MCP Server System

**Project-scoped configuration:**
- Each directory has independent server list via `.mcp-config`
- Auto-generates `.mcp.json` (Claude Code) and `.gemini-mcp.json` (Gemini CLI)
- Mode-aware: uses different env vars for personal/devsisters modes
- Commands: `mcp list`, `mcp enable <servers>`, `mcp disable <servers>`

**Available servers:** filesystem, nixos, github, terraform, notion, smithery-toolbox, blockscout (personal only), sequential-thinking, taskmaster, time

**Profiles are optional:** Global convenience collections, independent of project activation.

## VSCode Extensions

**Location:** `modules/vscode/extensions.nix`

**Required function signature:**
```nix
{ config, lib, pkgs, nix-vscode-extensions, ... }@inputs:
```

**Source priority:**
1. `pkgs.vscode-extensions.*` (nixpkgs curated - most reliable)
2. `nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace.*`
3. `nix-vscode-extensions.extensions.${pkgs.system}.open-vsx.*`
4. Custom builds (last resort)

**Critical gotchas:**
- Marketplace URLs frequently return 500 errors
- Nix caches evaluations - run `nix-collect-garbage` if seeing stale errors
- Test incremental changes: add one extension, build, test, repeat
- Never apply without successful build

**Custom extension pattern:**
```nix
(pkgs.vscode-utils.buildVscodeMarketplaceExtension {
  mktplcRef = {
    name = "extension-name";
    publisher = "publisher-name";
    version = "1.0.0";
    sha256 = "sha256-hash"; # Get via nix-prefetch-url
  };
})
```

## Testing Strategy

**Fast iteration (seconds, no builds):**
```bash
# 1. Flake structure validation
nix flake check

# 2. Evaluate specific config without building
nix eval --impure .#homeConfigurations.shavakan.config.home.packages --apply 'x: builtins.length x'

# 3. Test VSCode extensions evaluation
nix eval --impure .#homeConfigurations.shavakan.config.programs.vscode.profiles.default.extensions --apply 'x: builtins.length x'

# 4. Dry-run to see what would be built
nix build --dry-run --impure .#homeConfigurations.shavakan.activationPackage
```

**Full build test (minutes, before apply):**
```bash
home-manager build --flake . --impure
```

**When to use:**
- Config changes → fast eval tests first
- VSCode extension changes → specific extension eval test
- Before applying → full build test mandatory
- Stale errors after removing packages → `nix-collect-garbage -d`

## Workflow

1. Edit modules in `modules/`
2. **Fast test**: `nix flake check` or eval tests above
3. **Build test**: `home-manager build --flake . --impure`
4. **Apply**: `make home` (in background) OR `make darwin` (system)
5. **Format**: `nixpkgs-fmt **/*.nix`
6. **Lint**: `statix check`

## Development Shells

```bash
nix develop        # Formatting/linting tools
nix develop .#rust # Rust with fenix toolchain
```

## Logging

Services log to `~/nix-flakes/logs/` - check here for service debugging, especially rclone mount issues.
