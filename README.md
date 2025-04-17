# My Nix Development Environment

This repository contains my Nix flakes configuration for setting up a consistent development environment across machines.

## Prerequisites

1. Install Nix package manager:
   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

2. Enable Nix flakes (if not already enabled):
   ```bash
   mkdir -p ~/.config/nix
   echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
   ```

3. Install Home Manager:
   ```bash
   nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
   nix-channel --update
   ```

## Setup on a New Machine

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/nix-flakes.git ~/nix-flakes
   cd ~/nix-flakes
   ```

2. Copy your SSH key to the new machine (required for agenix decryption):
   ```bash
   # On your old machine
   scp ~/.ssh/id_ed25519 newmachine:~/.ssh/
   scp ~/.ssh/id_ed25519.pub newmachine:~/.ssh/
   
   # On the new machine, set proper permissions
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   ```

3. Install nix-darwin for macOS system configuration:
   ```bash
   # Clone the nix-darwin repository
   nix-build https://github.com/LnL7/nix-darwin/archive/master.tar.gz -A installer
   ./result/bin/darwin-installer
   
   # After installation, remove the build artifacts
   rm -rf result
   ```
   
   This will automatically install system dependencies like macFUSE through the Homebrew integration in your darwin.nix configuration.

4. Install oh-my-zsh for shell customization:
   ```bash
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   
   # Install powerlevel10k theme
   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
   ```

5. Apply the system and home configurations:
   ```bash
   cd ~/nix-flakes
   
   # First, apply the darwin system configuration
   # For MacBook:
   darwin-rebuild switch --flake .#MacBook-changwonlee
   
   # For Mac Studio:
   darwin-rebuild switch --flake .#macstudio-changwonlee
   
   # Then apply the Home Manager configuration
   LANG=en_US.UTF-8 home-manager switch --flake . --impure
   ```

## File Structure

```
.
├── flake.nix            # Main configuration entry point
├── flake.lock           # Locked dependencies
├── home.nix             # Home-manager user configuration
├── darwin.nix           # Main macOS system configuration shared by all machines
├── mcp-servers.nix       # Claude MCP server configuration
├── modules/
│   ├── agenix/           # Age-encrypted secrets
│   ├── awsctx/           # AWS context switcher
│   ├── darwin/           # Machine-specific configurations
│   └── rclone/           # Remote mounting configuration
└── README.md            # This file
```

This structure uses a shared darwin.nix for common settings, with machine-specific configurations in separate files.

## Key Features

This configuration includes:

- **Shell Environment**: ZSH with oh-my-zsh, powerlevel10k theme, and syntax highlighting plugins
- **Development Tools**: Git, Neovim, Terraform, various programming languages
- **Cloud Tools**: AWS CLI, Google Cloud SDK, kubectl, Vault
- **Custom Mounts**: rclone with automatic mounting of remote filesystems
- **Security**: GPG and SSH configuration with macOS keychain integration
- **System Configuration**: macOS settings and Homebrew package management via nix-darwin

## Automatic Mounts

The configuration includes automatic mounting of rclone filesystems. Ensure your rclone.conf is properly configured:

```bash
# Check mount status
rclone-status

# Mount manually if needed
rclone-mount aws-shavakan:shavakan-rclone ~/mnt/rclone
```

## Secrets Management

Secrets are managed using agenix and are automatically decrypted during configuration:

```bash
# Add a new secret
agenix -e secrets/newsecret.age -i ~/.ssh/id_ed25519.pub

# Edit an existing secret
agenix -e secrets/rclone.conf.age -i ~/.ssh/id_ed25519.pub
```

## Tips for Daily Usage

- Use the provided aliases for Git, Kubernetes, and other tools
- The devsisters.sh script is loaded from the rclone mount automatically
- Direnv is configured to automatically load environment variables from .envrc files

## Customization

To customize this configuration for your own use:

1. Edit `darwin.nix` for main system settings shared by all machines
2. Edit `modules/darwin/macbook.nix` or `modules/darwin/macstudio.nix` for machine-specific settings
3. Edit `home.nix` to adjust user packages and settings
4. Update `modules/rclone/*.nix` for custom remote mounts
5. Modify `modules/awsctx/awsctx.nix` for AWS integration settings
6. Update encrypted files using agenix in `modules/agenix/`

## Troubleshooting

- **SSH key issues**: Ensure your SSH key is properly set up at `~/.ssh/id_ed25519`
- **Mount errors**: Check `~/Library/Logs/rclone-mount.log` for details
- **Configuration errors**: Use `home-manager --debug switch --flake .` for verbose output
