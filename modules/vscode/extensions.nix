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

        # AI coding assistant
        github.copilot
        github.copilot-chat


        # Languages
        golang.go
        ms-python.python
        ms-python.vscode-pylance
        ms-python.debugpy

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
        zxh404.vscode-proto3
      ])

      # Extensions from VS Code Marketplace (via nix-vscode-extensions)
      ++ (with nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace; [
        # Git tools
        eamodio.gitlens

        # Additional Python tools not in nixpkgs
        ms-python.flake8
        ms-python.isort
        ms-python.pylint
      ])

      # Custom extensions (when nixpkgs versions have issues)
      ++ [
        (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
          mktplcRef = {
            name = "claude-code";
            publisher = "anthropic";
            version = "2.0.50";
            sha256 = "sha256-Pd4rRLS613/zSn8Pvr/cozaIAqrG06lmUC6IxHm97XQ=";
          };
        })
      ];
  };
}
