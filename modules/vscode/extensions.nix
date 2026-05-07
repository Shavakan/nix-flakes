{ config, lib, pkgs, nix-vscode-extensions, ... }@inputs:

{
  programs.vscode = {
    profiles.default.extensions =
      # Extensions curated in nixpkgs (most stable)
      (with pkgs.vscode-extensions; [
        # Nix support
        bbenoist.nix

        # Git integration
        github.vscode-pull-request-github

        # Languages
        golang.go
        ms-python.python
        ms-python.vscode-pylance
        ms-python.debugpy
        rust-lang.rust-analyzer

        # Tools
        ms-azuretools.vscode-docker
        ms-toolsai.jupyter
        hashicorp.terraform
        ms-kubernetes-tools.vscode-kubernetes-tools
        ms-vscode-remote.remote-containers

        # Editing experience
        asvetliakov.vscode-neovim
        yzhang.markdown-all-in-one
        redhat.vscode-yaml
      ])

      # Extensions from VS Code Marketplace (via nix-vscode-extensions overlay)
      ++ (with pkgs.vscode-marketplace; [
        # Git tools
        eamodio.gitlens

        # Additional Python tools not in nixpkgs
        ms-python.flake8
        ms-python.isort
        ms-python.pylint

        # AI coding assistants
        github.copilot-chat
        anthropic.claude-code
      ]);
  };
}
