{ config, lib, pkgs, ... }@inputs:

{
  programs.vscode = {
    profiles.default.extensions = 
      # Extensions available in nixpkgs (prefer these when available)
      (with pkgs.vscode-extensions; [
        # Nix support
        bbenoist.nix
        
        # Git integration
        eamodio.gitlens                # Enhanced Git functionality
        
        # AI coding assistant
        github.copilot                 # GitHub Copilot
        github.copilot-chat            # GitHub Copilot Chat
        
        # Languages
        golang.go                      # Go language support
        ms-python.python               # Python language support
        
        # Tools
        ms-azuretools.vscode-docker    # Docker integration
        ms-toolsai.jupyter             # Jupyter notebooks
        
        # Editing experience
        vscodevim.vim                  # Vim keybindings
        yzhang.markdown-all-in-one     # Markdown support
      ])
      
      # Extensions from VS Code Marketplace (for those not in nixpkgs)
      # Use the proper syntax for extensions with non-identifier names
      ++ (
        let
          marketplace = pkgs.vscode-marketplace;
        in
        [
          marketplace."766b".go-outliner # Access using explicit attribute syntax
        ]
      )
      ++ (with pkgs.vscode-marketplace; [
        # Other Go extensions
        aleksandra.go-group-imports
        premparihar.gotestexplorer
        maxmedia.go-prof
        
        # Database tools
        bajdzis.vscode-database
        
        # Utils and tools
        bbenoist.vagrant
        be5invis.toml
        davidanson.vscode-markdownlint
        docker.docker
        dsznajder.es7-react-js-snippets
        eriklynd.json-tools
        
        # GitHub integration
        github.vscode-pull-request-github
        
        # Python extensions
        guyskk.language-cython
        ms-python.debugpy
        ms-python.flake8
        ms-python.isort
        ms-python.pylint
        ms-python.vscode-pylance
        ms-toolsai.jupyter-keymap
        ms-toolsai.jupyter-renderers
        ms-toolsai.vscode-jupyter-cell-tags
        ms-toolsai.vscode-jupyter-slideshow
        
        # Infrastructure and DevOps
        hashicorp.terraform
        hollowtree.vue-snippets
        ipedrazas.kubernetes-snippets
        jmmeessen.jenkins-declarative-support
        ms-kubernetes-tools.vscode-kubernetes-tools
        ms-vscode-remote.remote-containers
        # ms-vscode.cpptools - REMOVED (not supported on arm64 Darwin)
        secanis.jenkinsfile-support
        
        # Collaboration
        # ms-vsliveshare.vsliveshare - REMOVED (not needed)
        # ms-vsliveshare.vsliveshare-pack - REMOVED (missing)
        
        # UI/UX and language packs
        ms-ceintl.vscode-language-pack-ko
        
        # Markdown and Documentation
        shd101wyy.markdown-preview-enhanced
        
        # Programming language support
        timonvs.reactsnippetsstandard
        xabikos.javascriptsnippets
        xmonader.vscode-capnp
        zxh404.vscode-proto3         # Protocol Buffers/gRPC support
        
        # YAML support
        redhat.vscode-yaml
      ]);
  };
}