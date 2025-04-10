{ config, pkgs, username, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage
  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    
    # Packages to install to the user profile
    packages = with pkgs; [
      # Development tools
      ripgrep
      fd
      jq
      fzf
      
      # CLI utilities
      tmux
      htop
      tree
      bat
      
      # Languages and development environments
      python3
      nodejs
    ];
    
    # This value determines the Home Manager release that your
    # configuration is compatible with.
    stateVersion = "23.11";
  };
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  
  # Enable and configure Git
  programs.git = {
    enable = true;
    userName = "Changwon Lee";
    userEmail = "shavakan@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
    };
  };
  
  # Configure ZSH
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;  # Updated from enableAutosuggestions
    enableCompletion = true;
    
    # Shell aliases
    shellAliases = {
      ll = "ls -la";
      ".." = "cd ..";
      "..." = "cd ../..";
      vi = "nvim";
      vim = "nvim";
    };
    
    # History settings
    history = {
      size = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      share = true;
    };
    
    # Extra config
    initExtra = ''
      # Custom zsh settings
      setopt AUTO_CD
      setopt HIST_IGNORE_SPACE
      
      # Path additions
      export PATH="$HOME/.local/bin:$PATH"
    '';
  };
  
  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;
}
