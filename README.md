### Other Issues

- **SSH key issues**: Ensure your SSH key is properly set up at `~/.ssh/id_ed25519`

- **Mount errors**: Check `~/Library/Logs/rclone-mount.log` for details on rclone mounting issues.

- **Package installation failures**: Some packages might fail to install. Try running `nix-collect-garbage -d` to clean up the Nix store, then retry the installation.# My Nix Development Environment

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

1. Install Nix package manager:
   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

2. Enable Nix flakes (if not already enabled):
   ```bash
   mkdir -p ~/.config/nix
   echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
   ```

3. Clone this repository:
   ```bash
   git clone <your-repo-url> ~/nix-flakes
   cd ~/nix-flakes
   ```

4. Copy your SSH key to the new machine (required for agenix decryption):
   ```bash
   # On your old machine
   scp ~/.ssh/id_ed25519 newmachine:~/.ssh/
   scp ~/.ssh/id_ed25519.pub newmachine:~/.ssh/
   
   # On the new machine, set proper permissions
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   ```

5. Install Homebrew (required for nix-darwin's Homebrew module):
   ```bash
   # Install Homebrew manually - nix-darwin can only manage an existing Homebrew installation
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   
   # Follow the instructions to add Homebrew to your PATH if prompted
   ```

6. Add the nix-darwin channel and install the basic framework:
   ```bash
   # Add the nix-darwin channel
   sudo nix-channel --add https://github.com/nix-darwin/nix-darwin/archive/master.tar.gz darwin
   sudo nix-channel --update
   
   # First install the darwin-rebuild command
   nix-build '<darwin>' -A darwin-rebuild

   cd ~/nix-flakes

   # Now apply your flake-based darwin configuration
   # For MacBook:
   ./result/bin/darwin-rebuild switch --flake .#MacBook-changwonlee
   
   # Or for Mac Studio:
   ./result/bin/darwin-rebuild switch --flake .#macstudio-changwonlee
   
   # Source the updated shell configuration
   source /etc/static/zshrc
   ```

7. Apply your flake-based configuration:
   ```bash
   cd ~/nix-flakes
   
   # Apply your home-manager configuration
   nix run home-manager/master -- switch --flake . --impure
   ```

8. Install oh-my-zsh for shell customization (optional):
   ```bash
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   
   # Install powerlevel10k theme
   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
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

### Homebrew Issues

- **Homebrew module error**: If you get `error: using the homebrew module requires homebrew installed`, you need to install Homebrew manually first using the command in step 5, then run nix-darwin again.

- **Homebrew path issues**: If Homebrew is installed but nix-darwin can't find it, make sure it's in your PATH. For Apple Silicon Macs, Homebrew is typically installed in `/opt/homebrew/bin/brew`.

### General Setup Issues

- **Home Manager not found**: If `home-manager` command is not found, use `nix run home-manager/master -- switch --flake . --impure` instead.

- **Shell environment not updated**: After initial installation, you may need to restart your terminal or run `source /etc/static/zshrc`.

- **Nix channel errors**: If you see errors about nix channels, you may need to run `nix-channel --update` before proceeding.
