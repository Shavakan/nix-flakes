# AWS Context (awsctx) Integration

This document explains how the `awsctx` tool has been integrated into your Nix configuration.

## Overview

The `awsctx` tool allows you to easily switch between different AWS profiles and contexts. It has been integrated into your Nix configuration to make it easier to manage and use.

## How to Apply the Changes

To apply the changes and start using `awsctx`, run:

```bash
cd ~/nix-flakes
home-manager switch --flake .
```

## How to Use

After applying the changes, you can use the following commands:

1. Login to all AWS profiles:
   ```bash
   aws-login-all
   ```

2. Switch to a specific AWS context:
   ```bash
   awsctx <context-name>
   ```
   For example:
   ```bash
   awsctx ck
   ```

## Directory Structure

The integration uses the following directories:

- Config files: `$HOME/Library/Application Support/awsctx`
- Credentials: `$HOME/Library/Caches/awsctx`
- Binary links: `$HOME/.local/bin`

## Shell Integration

The integration includes support for:

- Fish shell (with optional Tide prompt integration)
- Bash shell

## JetBrains IDEs

The following JetBrains IDEs have been added to your configuration:

- Rider (for .NET development)
- GoLand (for Go development)
- PyCharm Professional (for Python development)
- IntelliJ IDEA Ultimate (for Java and general development)

These IDEs will be installed and managed by Nix.

## Troubleshooting

If you encounter any issues:

1. Make sure `saml2aws` is properly configured:
   ```bash
   saml2aws configure
   ```

2. Check that the symbolic links are correctly set up:
   ```bash
   ls -la ~/.local/bin
   ```

3. Verify the config directories:
   ```bash
   ls -la ~/Library/Application\ Support/awsctx
   ls -la ~/Library/Caches/awsctx
   ```
