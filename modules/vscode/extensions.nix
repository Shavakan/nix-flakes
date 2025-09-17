{ config, lib, pkgs, ... }@inputs:

{
  programs.vscode = {
    profiles.default.extensions =
      # Extensions available in nixpkgs (prefer these when available)
      (with pkgs.vscode-extensions; [
        # Nix support
        bbenoist.nix

        # Git integration
        eamodio.gitlens # Enhanced Git functionality
        github.vscode-pull-request-github # GitHub PR integration

        # AI coding assistant
        github.copilot # GitHub Copilot
        github.copilot-chat # GitHub Copilot Chat

        # Languages
        golang.go # Go language support
        ms-python.python # Python language support

        # Tools
        ms-azuretools.vscode-docker # Docker integration
        ms-toolsai.jupyter # Jupyter notebooks

        # Editing experience
        asvetliakov.vscode-neovim # Neovim integration
        yzhang.markdown-all-in-one # Markdown support
        redhat.vscode-yaml # YAML support
        zxh404.vscode-proto3 # Protocol Buffers/gRPC support
      ])

      # Extensions from nix-vscode-extensions (confirmed available)
      ++ (with pkgs.vscode-extensions; [
        # Core tools
        ms-python.vscode-pylance
        ms-python.python
        ms-python.debugpy
        ms-python.flake8
        ms-python.isort
        ms-python.pylint
        hashicorp.terraform
        ms-kubernetes-tools.vscode-kubernetes-tools
        ms-vscode-remote.remote-containers
      ])

      # Additional verified extensions from nix-vscode-extensions
      ++ (with pkgs.vscode-extensions; [
        # Only use confirmed working extensions for now
        # TODO: Add custom extensions when we can determine proper access pattern
      ]);
  };
}
