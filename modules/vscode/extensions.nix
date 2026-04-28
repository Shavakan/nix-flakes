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
            name = "copilot-chat";
            publisher = "github";
            version = "0.43.2026040705";
            sha256 = "sha256-iXfRR96wPTmzkvYXSxMWe9PkW/Er5Mx24k9zRF9U1pg=";
          };
        })
        (pkgs.vscode-utils.buildVscodeMarketplaceExtension {
          mktplcRef = {
            name = "claude-code";
            publisher = "anthropic";
            version = "2.1.116";
            sha256 = "sha256-myBC6iy7EsA1at4QKWjgiq3TRuC4VMqeH4jop9zo4BM=";
          };
        })
      ];
  };
}
