{ config, pkgs, lib, hostname, zsh-powerlevel10k, zsh-autopair, vim-nord, vim-surround, vim-commentary, vim-easy-align, fzf-vim, vim-fugitive, vim-nix, vim-terraform, vim-go, saml2aws, ... }@args:

{
  imports = [
    ./modules/themes
    ./modules/ls-colors
    ./modules/rclone
    ./modules/awsctx
    ./modules/git
    ./modules/neovim
    ./modules/zsh
    ./modules/claude
    ./modules/vscode
    ./modules/cargo
    ./modules/iterm2
    ./modules/spotlight
    ./modules/podman
    ./modules/mcp-servers
  ];

  # Home Manager needs a bit of information about you and the paths it should manage
  home = {
    username = "shavakan";
    homeDirectory = "/Users/shavakan";

    # Set language for shell sessions managed by home-manager
    language = {
      base = "en_US.UTF-8";
    };

    # Common logging framework for all activation scripts
    activation.setupLogging = lib.hm.dag.entryBefore [ ] ''
      # Create log directory
      export NIX_LOG_DIR="$HOME/nix-flakes/logs"
      mkdir -p "$NIX_LOG_DIR" > /dev/null 2>&1
      
      # Common log function that all activation scripts can use
      log_nix() {
        local component="$1"
        local message="$2"
        local log_file="$NIX_LOG_DIR/$component.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
      }
      
      # Export the function so it's available to all activation scripts
      export -f log_nix
    '';

    # Packages to install to the user profile
    packages = with pkgs; [
      # System utilities
      coreutils
      findutils

      # Development languages and tools
      terraform
      dotnet-sdk
      buf
      subversion
      golangci-lint
      ruby

      # Cloud tools
      kubectl
      kubectx
      k9s
      kubernetes-helm
      awscli2
      google-cloud-sdk
      gemini-cli

      # Search tools
      ripgrep

      # Git tools
      github-cli

      # Data processing tools
      yq

      # ZSH Enhancements
      zsh-powerlevel10k

      # GPG
      gnupg

      # Secrets management
      agenix
      vault
      _1password-cli
      _1password-gui

      # System utilities
      watch
      pre-commit
      nixpkgs-fmt
      statix


      # Tools
      obsidian
      code-cursor

      # Terminal

      # Communication
      slack

      # JetBrains IDEs
      jetbrains.rider
      jetbrains.goland
      jetbrains.pycharm-professional
      # jetbrains.idea-ultimate  # Temporarily disabled due to build failure
      jetbrains.datagrip
      jetbrains.rust-rover

      # Misc
      direnv
      codex
      gemini-cli
      teleport
    ];

    # This value determines the Home Manager release compatibility
    stateVersion = "24.11";
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
  };

  # Disable showing news on update
  news.display = "silent";

  # Tmux configuration
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1;
    terminal = "screen-256color";
    escapeTime = 0;
    historyLimit = 10000;

    mouse = true;
    keyMode = "vi";
    customPaneNavigationAndResize = true;
    aggressiveResize = true;
    clock24 = true;
    newSession = true;

    extraConfig = ''
      # Additional tmux configuration
      set -g status-style "bg=black,fg=white"

      # Synchronize panes
      bind-key sp set-window-option synchronize-panes\; display-message "synchronize-panes is now #{?pane_synchronized,on,off}"
    '';
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Configure rclone services in the correct dependency order
  services.rclone = {
    enable = true;
    configFile = ./modules/agenix/rclone.conf.age;
  };

  # Configure rclone mounting service with comprehensive configuration linking
  services.rclone-mount = {
    enable = true;
    mounts = [
      {
        remote = "aws-shavakan:shavakan-rclone";
        mountPoint = "${config.home.homeDirectory}/mnt/rclone";
        allowOther = false;
      }
    ];

    # Configure all files that should be linked from the mount directory
    linkedConfigurations = [
      {
        name = "kubeconfig";
        sourcePath = "kubeconfig";
        targetPath = "${config.home.homeDirectory}/.kube/config";
        permissions = "600";
        createTargetDir = true;
        backupExisting = true;
      }
      {
        name = "saml2aws";
        sourcePath = "saml2aws";
        targetPath = "${config.home.homeDirectory}/.saml2aws";
        permissions = "600";
        createTargetDir = true;
        backupExisting = true;
      }
      {
        name = "devsisters-script";
        sourcePath = "devsisters.sh";
        targetPath = "${config.home.homeDirectory}/.devsisters.sh";
        permissions = "755";
        createTargetDir = false;
        backupExisting = true;
      }
      {
        name = "personal-script";
        sourcePath = "personal.sh";
        targetPath = "${config.home.homeDirectory}/.personal.sh";
        permissions = "755";
        createTargetDir = false;
        backupExisting = true;
      }
      {
        name = "claude-config";
        sourcePath = "claude/CLAUDE.md";
        targetPath = "${config.home.homeDirectory}/.claude/CLAUDE.md";
        permissions = "644";
        createTargetDir = true;
        backupExisting = true;
      }
      {
        name = "claude-settings";
        sourcePath = "claude/settings.json";
        targetPath = "${config.home.homeDirectory}/.claude/settings.json";
        permissions = "644";
        createTargetDir = true;
        backupExisting = true;
      }
      {
        name = "claude-local-settings";
        sourcePath = "claude/settings.local.json";
        targetPath = "${config.home.homeDirectory}/.claude/settings.local.json";
        permissions = "644";
        createTargetDir = true;
        backupExisting = true;
      }
    ];

    # Environment variables for linked configurations
    environmentVariables = {
      KUBECONFIG = "${config.home.homeDirectory}/.kube/config";
    };
  };

  # Enable cd-rclone for easier navigation to rclone mount directories
  programs.cd-rclone = {
    enable = true;
    extraDirs = {
      kube = "kubeconfigs";
    };
  };

  # Enable the rclone-launchd service last to avoid circular dependencies
  services.rclone-launchd = {
    enable = true;
  };

  themes.selected = "nord";

  # Unified MCP Server Configuration
  services.mcp-servers = {
    enable = true;
    servers = {
      filesystem = {
        enable = true;
        command = "/run/current-system/sw/bin/npx";
        args = [ "@modelcontextprotocol/server-filesystem" "/Users/shavakan/Desktop" "/Users/shavakan/Downloads" "/Users/shavakan/nix-flakes" "/Users/shavakan/workspace" ];
        clients = [ "claude-code" "claude-desktop" "gemini-cli" ];
        description = "Provides filesystem access to AI tools";
        environments = {
          default = { };
          personal = { };
          devsisters = { };
        };
      };

      nixos = {
        enable = true;
        command = "/run/current-system/sw/bin/uvx";
        args = [ "mcp-nixos" ];
        clients = [ "claude-code" "claude-desktop" "gemini-cli" ];
        description = "NixOS package search and management";
        environments = {
          default = { };
          personal = { };
          devsisters = { };
        };
      };

      github = {
        enable = true;
        command = "/run/current-system/sw/bin/podman";
        args = [ "run" "-i" "--rm" "-e" "GITHUB_PERSONAL_ACCESS_TOKEN" "ghcr.io/github/github-mcp-server" "stdio" ];
        clients = [ "claude-desktop" "gemini-cli" ];
        description = "GitHub repository and issue management";
        environments = {
          default = {
            GITHUB_PERSONAL_ACCESS_TOKEN = "$GITHUB_PERSONAL_ACCESS_TOKEN";
          };
          personal = {
            GITHUB_PERSONAL_ACCESS_TOKEN = "$GITHUB_PERSONAL_ACCESS_TOKEN";
          };
          devsisters = {
            GITHUB_PERSONAL_ACCESS_TOKEN = "$GITHUB_WORK_ACCESS_TOKEN";
          };
        };
      };

      terraform = {
        enable = true;
        command = "/run/current-system/sw/bin/podman";
        args = [ "run" "-i" "--rm" "hashicorp/terraform-mcp-server" ];
        clients = [ "claude-desktop" "gemini-cli" ];
        description = "Terraform infrastructure management";
        environments = {
          default = { };
          personal = { };
          devsisters = {
            TF_VAR_environment = "production";
            AWS_PROFILE = "saml";
          };
        };
      };

      notion = {
        enable = true;
        command = "/run/current-system/sw/bin/npx";
        args = [ "@notionhq/notion-mcp-server" ];
        clients = [ "claude-desktop" "gemini-cli" ];
        description = "Notion workspace integration";
        environments = {
          default = {
            NOTION_API_KEY = "$NOTION_API_KEY";
          };
          personal = {
            NOTION_API_KEY = "$NOTION_PERSONAL_API_KEY";
            NOTION_DATABASE_ID = "$NOTION_PERSONAL_DATABASE_ID";
          };
          devsisters = {
            NOTION_API_KEY = "$NOTION_WORK_API_KEY";
            NOTION_DATABASE_ID = "$NOTION_WORK_DATABASE_ID";
          };
        };
      };

      # Smithery MCP Servers
      smithery-toolbox = {
        enable = true;
        command = "/run/current-system/sw/bin/npx";
        args = [ "@smithery/cli" "run" "@smithery/toolbox" ];
        clients = [ "claude-code" "claude-desktop" "gemini-cli" ];
        description = "Smithery toolbox for enhanced AI capabilities";
        environments = {
          default = { };
          personal = { };
          devsisters = { };
        };
      };

      blockscout = {
        enable = true;
        command = "/run/current-system/sw/bin/npx";
        args = [ "@smithery/cli" "run" "@blockscout/mcp-server" ];
        clients = [ "claude-code" "claude-desktop" "gemini-cli" ];
        description = "Blockscout blockchain explorer integration (personal only)";
        environments = {
          personal = { };
          # Only available in personal mode
        };
      };

      sequential-thinking = {
        enable = true;
        command = "/run/current-system/sw/bin/npx";
        args = [ "@modelcontextprotocol/server-sequential-thinking" ];
        clients = [ "claude-code" "claude-desktop" "gemini-cli" ];
        description = "Sequential thinking and reference management";
        environments = {
          default = { };
          personal = { };
          devsisters = { };
        };
      };

      taskmaster = {
        enable = true;
        command = "/run/current-system/sw/bin/npx";
        args = [ "-y" "--package=task-master-ai" "task-master-ai" ];
        clients = [ "claude-code" "claude-desktop" "gemini-cli" ];
        description = "Task management and organization";
        environments = {
          default = {
            ANTHROPIC_API_KEY = "\${ANTHROPIC_API_KEY}";
            OPENAI_API_KEY = "\${OPENAI_API_KEY}";
          };
          personal = {
            ANTHROPIC_API_KEY = "\${ANTHROPIC_API_KEY}";
            OPENAI_API_KEY = "\${OPENAI_API_KEY}";
          };
          devsisters = {
            ANTHROPIC_API_KEY = "\${ANTHROPIC_API_KEY}";
            OPENAI_API_KEY = "\${OPENAI_API_KEY}";
          };
        };
      };

      time = {
        enable = true;
        command = "/run/current-system/sw/bin/npx";
        args = [ "time-mcp" ];
        clients = [ "claude-code" "claude-desktop" "gemini-cli" ];
        description = "Time management and scheduling utilities";
        environments = {
          default = { };
          personal = { };
          devsisters = { };
        };
      };

      astrotask = {
        enable = true;
        command = "/run/current-system/sw/bin/npx";
        args = [ "@astrotask/mcp" ];
        clients = [ "claude-code" "claude-desktop" "gemini-cli" ];
        description = "Astrotask local-first task management platform";
        environments = {
          default = { };
          personal = { };
          devsisters = { };
        };
      };

      claude-task-master = {
        enable = true;
        command = "/run/current-system/sw/bin/npx";
        args = [ "@smithery/cli" "run" "@eyaltoledano/claude-task-master" ];
        clients = [ "claude-code" "claude-desktop" "gemini-cli" ];
        description = "AI-powered comprehensive task management system";
        environments = {
          default = { };
          personal = { };
          devsisters = { };
        };
      };
    };
  };


  # Mac App Store applications
  services.mas = {
    enable = true;
    appleId = "chiyah92@icloud.com";
    apps = {
      "Paste" = 967805235;
      "WireGuard" = 1451685025;
    };
  };

  # Enhanced GPG configuration
  programs.gpg = {
    enable = true;
    settings = {
      no-symkey-cache = true;
      use-agent = true;
      pinentry-mode = "loopback";
    };
  };

  # Configure GPG agent (without SSH support since we're using macOS SSH agent)
  services.gpg-agent = {
    enable = true;
    enableSshSupport = false;
    enableExtraSocket = true;
    defaultCacheTtl = 3600;
    maxCacheTtl = 86400;
    pinentry.package = pkgs.pinentry_mac;
    extraConfig = ''
      allow-loopback-pinentry
      allow-emacs-pinentry
      allow-preset-passphrase
    '';
  };

  # Enable awsctx service
  services.awsctx = {
    enable = true;
  };

  # Configure SSH with proper agent setup
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = {
        identityFile = [
          "~/.ssh/id_rsa"
          "~/.ssh/id_ecdsa"
          "~/.ssh/id_ed25519"
        ];
      };
      
      "github.com" = {
        hostname = "ssh.github.com";
        port = 443;
        user = "git";
      };
    };

    extraConfig = ''
      AddKeysToAgent yes
      IdentitiesOnly yes
    '';
  };
}
