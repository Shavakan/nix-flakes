{ config, lib, pkgs, ... }:

with lib;

{
  # Declaratively configure Git using home-manager's built-in support
  programs.git = {
    enable = true;
    userName = "ChangWon Lee";
    userEmail = "cs.changwon.lee@gmail.com";

    # Note: We're not setting signing here since it's handled by the host-config activation script

    # Enable git-lfs
    lfs.enable = true;

    # All Git configuration in one place
    extraConfig = {
      core = {
        editor = "nvim";
        excludesfile = "~/.gitignore_global";
      };

      # Merge configuration
      merge = {
        tool = "vimdiff";
        conflictstyle = "diff3";
      };

      # Diff configuration
      diff = {
        tool = "vimdiff";
      };

      # Tool configuration for both diff and merge
      difftool = {
        prompt = false;
        trustExitCode = true;
      };

      mergetool = {
        vimdiff.cmd = "nvim -d $LOCAL $REMOTE $MERGED -c '$wincmd w' -c '$wincmd J'";
        keepBackup = false;
        prompt = false;
        trustExitCode = true;
      };

      # Pull configuration
      pull = {
        rebase = true;
        ff = "only";
      };

      # Push configuration
      push = {
        default = "current";
        autoSetupRemote = true;
      };

      # Remote URL configuration - prefer SSH over HTTPS
      url = {
        "git@github.com:".insteadOf = "https://github.com/";
        "git@gitlab.com:".insteadOf = "https://gitlab.com/";
        # Keep this for compatibility with some tools that only use git://
        "https://".insteadOf = "git://";
      };

      # Useful aliases
      alias = {
        lg = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
        s = "status -s";
        c = "commit";
        ca = "commit --amend";
        co = "checkout";
        cob = "checkout -b";
        br = "branch";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "!gitk";
        untrack = "rm --cached";
      };

      # Color configuration
      color = {
        ui = "auto";
        diff = "auto";
        status = "auto";
        branch = "auto";
      };

      # Rebase configuration
      rebase = {
        autostash = true;
        autosquash = true;
      };

      # Init configuration
      init = {
        defaultBranch = "main";
      };
    };

    # Delta for better diffs with improved color visibility
    delta = {
      enable = true;
      options = {
        navigate = true;
        light = false;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "Dracula"; # Better visibility than Nord in dark mode
        # Custom color settings for better visibility
        plus-style = "syntax #2A5A2A"; # Brighter green for additions
        minus-style = "syntax #5A2A2A"; # Brighter red for deletions
        plus-emph-style = "syntax #3A6A3A"; # Even brighter green for emphasized additions
        minus-emph-style = "syntax #6A3A3A"; # Even brighter red for emphasized deletions
        line-numbers-plus-style = "#3A7A3A"; # Brighter green for line numbers in additions
        line-numbers-minus-style = "#7A3A3A"; # Brighter red for line numbers in deletions
        # High contrast theme options
        hunk-header-style = "syntax bold"; # Make hunk headers bold
        file-style = "yellow bold"; # Bright yellow for file names
        file-decoration-style = "yellow ul"; # Underline file names
      };
    };
  };

  # Create global gitignore file
  home.file.".gitignore_global".text = ''
    # Go delve test file
    debug.test

    # Vim swap files
    *.sw[op]
    .*.sw[op]
    *~

    # Vim plugins
    .ropeproject/

    # macOS
    .DS_Store
    .AppleDouble
    .LSOverride
    ._*
    .Spotlight-V100
    .Trashes

    # VS Code
    .vscode/
    .history/

    # IntelliJ
    .idea/
    *.iml
    *.iws
    *.ipr
    out/
    .idea_modules/

    # Terraform
    .terraform/
    terraform.tfstate
    terraform.tfstate.backup
    .terraform.lock.hcl
    .tool-versions

    # direnv
    .envrc
    .direnv/

    # Python
    *.py[cod]
    __pycache__/
    .pytest_cache/
    .coverage
    htmlcov/
    .mypy_cache/

    # Node
    node_modules/
    npm-debug.log*
    yarn-debug.log*
    yarn-error.log*
    .pnp.*
    .npm
    .yarn/
    
    # Claude
    .claude/

    # Logs
    logs
    *.log
  '';
}
