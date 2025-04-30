# My Nix Development Environment

This repository contains my Nix flakes configuration for setting up a consistent development environment across machines using nix-darwin and home-manager.

## Setup

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/nix-flakes.git ~/nix-flakes
cd ~/nix-flakes

# Apply system configuration
darwin-rebuild switch --flake . --impure

# Apply user configuration
home-manager switch --flake . --impure
```

### Updating

```bash
# Update flake inputs
nix flake update

# Apply changes
darwin-rebuild switch --flake . --impure
home-manager switch --flake . --impure
```

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
   git clone git@github.com:Shavakan/nix-flakes.git ~/nix-flakes
   cd ~/nix-flakes
   ```

2. Set up SSH for the new machine:
   ```bash
   # Generate a new SSH key on the new machine
   ssh-keygen -t ed25519 -C "your-email@example.com"
   
   # Display your public key to copy
   cat ~/.ssh/id_ed25519.pub
   
   # Add the public key to modules/agenix/ssh.nix in your repository
   # Edit the file and add your key to the list - it should look something like:
   # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-email@example.com"
   
   # Commit this change and push to your repository
   git add modules/agenix/ssh.nix
   git commit -m "Add new machine's SSH key"
   git push
   
   # On existing machines, pull the changes and rekey the secrets
   # This allows the new machine to decrypt the secrets
   git pull
   agenix --rekey
   ```

3. Install Homebrew (required for nix-darwin's Homebrew module):
   ```bash
   # Install Homebrew manually - nix-darwin can only manage an existing Homebrew installation
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   
   # Follow the instructions to add Homebrew to your PATH if prompted
   ```

4. Add the nix-darwin channel and install the basic framework:
   ```bash
   # Add the nix-darwin channel
   sudo nix-channel --add https://github.com/nix-darwin/nix-darwin/archive/master.tar.gz darwin
   sudo nix-channel --update
   
   # First install the darwin-rebuild command
   nix-build '<darwin>' -A darwin-rebuild

   cd ~/nix-flakes

   # Build and apply the configuration using your hostname
   ./result/bin/darwin-rebuild switch --flake .#$(hostname) --impure
   
   # Source the updated shell configuration
   source /etc/static/zshrc
   ```

5. Apply your flake-based configuration:
   ```bash
   cd ~/nix-flakes
   
   # Apply your home-manager configuration
   nix run home-manager/master -- switch --flake . --impure
   ```

   This will set up your complete environment including ZSH with Oh-My-Zsh and the powerlevel10k theme, which are configured in the `modules/zsh/default.nix` module.
   
   When you first launch your terminal after installation, the powerlevel10k configuration wizard will run automatically. Follow the prompts to set up your preferred terminal appearance.

## iTerm2 Configuration

Your iTerm2 terminal is configured through nix-darwin, which manages settings, profiles, and appearance preferences declaratively.

### Features

- **Profile Management**: The default profile is based on the provided Default.json, with support for additional custom profiles
- **Theme Integration**: Auto-detects system dark/light mode when theme is set to "auto"
- **Visual Customization**: Controls transparency, blur, colors, fonts, and cursor style
- **Status Bar**: Configurable status bar with various components (CPU, memory, etc.)
- **Smart Selection**: Enables intelligent text selection for URLs, file paths, etc.

### Applying Changes

When making changes to the iTerm2 configuration in `modules/darwin/services/iterm2.nix`, you must use the `--impure` flag with darwin-rebuild:

```bash
darwin-rebuild switch --flake . --impure
```

The `--impure` flag is required because the configuration detects your system's current dark/light mode setting when using the "auto" theme option.

### Adding Custom Profiles

You can add custom profiles by editing the `custom.iterm2.profiles` section in `modules/darwin/services/default.nix`:

```nix
profiles = {
  "Work" = {
    default = false;
    name = "Work";
    font = "MesloLGS-NF-Regular";
    fontSize = 13;
    useNonAsciiFont = false;
    # Additional settings...
  };
};
```

### Advanced Preferences

Additional iTerm2 preferences can be configured via the `advancedPreferences` option:

```nix
advancedPreferences = {
  "AlternateMouseScroll" = true;
  "AutoCommandHistory" = true;
  "SoundForEsc" = false;
  # Additional preferences...
};
```

## Keyboard Shortcuts

### Stage Manager Toggle

**Command (⌘) + Option (⌥) + S**: Toggle Stage Manager on/off  
**Option (⌥) + Shift (⇧) + D**: Alternative shortcut to toggle Stage Manager

This allows you to quickly enable or disable Stage Manager when you need to view multiple windows at once or focus on a single app.

An executable script is also placed on your Desktop ("Toggle Stage Manager.command") that you can double-click to toggle Stage Manager manually.

> **Note**: For the keyboard shortcuts to work:
>
> 1. You'll need to grant skhd permission in System Settings → Privacy & Security → Accessibility
> 2. If the shortcuts stop working, disable Secure Keyboard Entry in Terminal/iTerm2
> 3. All logs are stored in `~/.config/skhd/logs/` for troubleshooting

## File Structure

```
.
├── flake.nix            # Main configuration entry point
├── flake.lock           # Locked dependencies
├── home.nix             # Home-manager user configuration
├── modules/
│   ├── agenix/          # Age-encrypted secrets
│   ├── awsctx/          # AWS context switcher
│   ├── darwin/          # Machine-specific configurations
│   │   ├── default.nix  # Shared darwin configuration (main module)
│   │   ├── macbook.nix  # MacBook configuration
│   │   ├── macstudio.nix # Mac Studio configuration
│   │   └── services/    # Services modules
│   │       ├── default.nix      # Services configuration
│   │       ├── iterm2.nix       # iTerm2 configuration
│   │       └── stage-manager.nix # Stage Manager module
│   ├── host-config/     # Machine type detection and settings
│   ├── pre-commit/      # Pre-commit hooks configuration
│   └── rclone/          # Remote mounting configuration
└── README.md            # This file
```

## Host-specific Configuration

This setup uses per-machine configurations based on hostname:

1. Apply your configuration using:
   ```bash
   darwin-rebuild switch --flake .#$(hostname) --impure
   ```

2. To add a new machine:
   - Add an entry to `flake.nix` with your hostname
   - Update machine type detection in `modules/host-config/git.nix`

## Secrets Management

Secrets are managed using agenix and are automatically decrypted during configuration.

### Setting Up SSH Keys for Agenix

1. Generate an SSH key (if you haven't already):
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

2. Add your public key to `modules/agenix/ssh.nix`

3. Commit and push the changes

### Managing Secrets

```bash
# Add a new secret
agenix -e modules/agenix/newsecret.age -i ~/.ssh/id_ed25519.pub

# Edit an existing secret
agenix -e modules/agenix/rclone.conf.age -i ~/.ssh/id_ed25519.pub
```

### Rekeying Secrets for New Machines

When adding a new machine to your setup:

1. On the new machine, generate a new SSH key and add its public key to `modules/agenix/ssh.nix`

2. On an existing machine with access to the secrets:
   ```bash
   # Pull the updated ssh.nix file
   git pull
   
   # Rekey all secrets
   cd ~/nix-flakes
   agenix --rekey
   ```

3. Commit and push the changes:
   ```bash
   git add modules/agenix/rclone.conf.age
   git commit -m "Rekey secrets for new machine"
   git push
   ```

4. The hash checking is automatic - when you run `home-manager switch`, the `decryptRcloneConfig` activation script in `modules/rclone/rclone.nix` automatically calculates and stores the new hash.

Never copy private SSH keys between machines. Always generate unique keys for each machine.

## Setting Up Git Commit Signing

### Generating a GPG Key

1. Install GPG (already included in your configuration)

2. Generate a new GPG key:
   ```bash
   # Start the key generation process
   gpg --full-generate-key
   ```
   - Choose `RSA and RSA` (option 1)
   - Choose a key size of `4096`
   - Choose a validity period that works for you (0 = never expires)
   - Enter your name and email address (use the same email as your git configuration)
   - Set a secure passphrase

3. List your GPG keys to get the key ID:
   ```bash
   gpg --list-secret-keys --keyid-format=long
   ```
   - Look for a line like `sec   rsa4096/01FA3FC79AD70686` - the part after the slash is your key ID

4. Export your public key to add to GitHub/GitLab:
   ```bash
   gpg --armor --export 01FA3FC79AD70686 | pbcopy
   ```
   - This copies your public key to clipboard. Add it to your GitHub/GitLab account settings.

### Adding GPG Key to Your Configuration

1. Update the GPG key ID in your machine configuration at `modules/host-config/default.nix`:

   Look for a section like this and add/modify your machine's entry:
   ```nix
   # Machine configs for different machine types
   machineConfigs = {
     "macbook" = {
       gitSigningKey = "YOUR_GPG_KEY_ID_HERE"; # E.g., "01FA3FC79AD70686"
       enableGitSigning = true;
     };
   };
   ```

2. Apply your configuration:
   ```bash
   darwin-rebuild switch --flake .
   LANG=en_US.UTF-8 home-manager switch --flake . --impure
   ```

## Troubleshooting

### Homebrew Issues

- **Homebrew module error**: If you get `error: using the homebrew module requires homebrew installed`, you need to install Homebrew manually first, then run nix-darwin again.

- **Homebrew path issues**: If Homebrew is installed but nix-darwin can't find it, make sure it's in your PATH. For Apple Silicon Macs, Homebrew is typically installed in `/opt/homebrew/bin/brew`.

### skhd Issues

- **Keyboard shortcuts not working**: Ensure Secure Keyboard Entry is disabled in your terminal (Terminal → Secure Keyboard Entry) and check accessibility permissions.

- **skhd failing to start**: Run `~/Desktop/restart_skhd.command` to diagnose and restart the service.

### Other Issues

- **SSH key issues**: Ensure your SSH key is properly set up at `~/.ssh/id_ed25519`

- **Secrets decryption fails**: Ensure your SSH key is added to `modules/agenix/ssh.nix` and the secrets have been rekeyed with `agenix --rekey` on an existing machine.

## Features

- **Centralized system configuration** using nix-darwin
- **User environment management** with home-manager
- **Machine-specific configurations** (MacBook vs Mac Studio)
- **Shell Environment**: ZSH with oh-my-zsh and powerlevel10k theme
- **Development Tools**: Git, Neovim, Terraform, various programming languages
- **Cloud Tools**: AWS CLI, Google Cloud SDK, kubectl, Vault
- **Custom Mounts**: rclone with automatic mounting of remote filesystems
- **Security**: GPG and SSH configuration with macOS keychain integration
- **Machine-specific Configuration**: Automatic detection and configuration for different machines
- **System Configuration**: macOS settings and Homebrew package management via nix-darwin
- **Code Quality**: Pre-commit hooks with nixpkgs-fmt and statix for consistent Nix code
- **Stage Manager Shortcuts**: Easy toggling via keyboard shortcuts
