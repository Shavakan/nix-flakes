{ config, lib, pkgs, ... }@inputs:

{
  programs.vscode = {
    profiles.default.userSettings = {
      # Neovim integration
      "vscode-neovim.neovimExecutablePaths.darwin" = "/Users/shavakan/.nix-profile/bin/nvim";
      "vscode-neovim.useWSL" = false;
      "vscode-neovim.logLevel" = "warn";
      "vscode-neovim.logOutputToConsole" = true;
      
      # Extension settings
      "extensions.ignoreRecommendations" = false;
      
      # Editor preferences
      "editor.renderWhitespace" = "boundary";
      "editor.wordWrap" = "on";
      "editor.formatOnSave" = true;
      "editor.formatOnPaste" = true;
      "editor.detectIndentation" = true;
      "editor.codeLens" = true;
      "editor.cursorBlinking" = "phase";
      "editor.rulers" = [
          80
          120
      ];
      
      # File handling
      "files.insertFinalNewline" = true;
      "files.autoSave" = "off";
      
      # HTML settings
      "html.autoClosingTags" = true;
      
      # GitLens settings
      "gitlens.keymap" = "alternate";
      "gitlens.historyExplorer.enabled" = true;
      "gitlens.views.fileHistory.enabled" = true;
      "gitlens.views.lineHistory.enabled" = true;
      "gitlens.advanced.messages" = {
          "suppressCommitHasNoPreviousCommitWarning" = false;
          "suppressCommitNotFoundWarning" = false;
          "suppressFileNotUnderSourceControlWarning" = false;
          "suppressGitVersionWarning" = false;
          "suppressLineUncommittedWarning" = false;
          "suppressNoRepositoryWarning" = false;
          "suppressResultsExplorerNotice" = false;
          "suppressShowKeyBindingsNotice" = true;
          "suppressUpdateNotice" = false;
          "suppressWelcomeNotice" = true;
      };
      
      # Python settings
      "python.linting.pycodestyleEnabled" = true;
      "python.linting.pycodestyleArgs" = [
          "--ignore=E501"
          "--max-line-length=120"
      ];
      "python.linting.pylintArgs" = [
          "--max-line-length=120"
      ];
      "python.formatting.provider" = "autopep8";
      "python.formatting.autopep8Args" = [
          "--max-line-length=120"
      ];
      
      # Language-specific settings
      "[terraform]" = {
          "editor.formatOnSave" = true;
          "editor.tabSize" = 2;
      };
      "[capnp]" = {
          "editor.tabSize" = 2;
      };
      "[go]" = {
          "editor.snippetSuggestions" = "none";
          "editor.formatOnSave" = true;
          "editor.codeActionsOnSave" = {
              "source.organizeImports" = true;
          };
      };
      
      # Go settings
      "go.lintFlags" = [
          "--enable-all"
      ];
      "go.autocompleteUnimportedPackages" = true;
      "go.gotoSymbol.includeGoroot" = true;
      "go.formatTool" = "goimports";
      "go.gocodeAutoBuild" = true;
      "go.gotoSymbol.includeImports" = true;
      "go.liveErrors" = {
          "enabled" = false;
          "delay" = 500;
      };
      "go.toolsEnvVars" = {
          "GO111MODULE" = "on";
      };
      "go.useLanguageServer" = true;
      "go.languageServerFlags" = [
          "-rpc.trace"
          "serve"
          "--debug=localhost:6060"
          "--logfile=/tmp/gopls.log"
      ];
      "go.lintTool" = "golangci-lint";
      
      # Gopls settings
      "gopls" = {
          "usePlaceholders" = true;
      };
      
      # Kubernetes settings
      "vs-kubernetes" = {
          "vs-kubernetes.minikube-path" = "/Users/changwonlee/.vs-kubernetes/tools/minikube/darwin-amd64/minikube";
          "vs-kubernetes.minikube-path.mac" = "/Users/changwonlee/.vs-kubernetes/tools/minikube/darwin-amd64/minikube";
          "vs-kubernetes.kubectl-path.mac" = "/Users/changwonlee/.vs-kubernetes/tools/kubectl/kubectl";
          "vs-kubernetes.helm-path.mac" = "/Users/changwonlee/.vs-kubernetes/tools/helm/darwin-amd64/helm";
          "vs-kubernetes.draft-path.mac" = "/Users/changwonlee/.vs-kubernetes/tools/draft/darwin-amd64/draft";
      };
      
      # YAML settings
      "yaml.format.enable" = false;
      
      # Jsonnet settings
      "jsonnet.libPaths" = [];
      "jsonnet.executablePath" = "/usr/local/bin/jsonnet";
      "jsonnet.extStrs" = {};
      
      # Merge conflict settings
      "merge-conflict.autoNavigateNextConflict.enabled" = true;
      
      # Docker settings
      "docker.showStartPage" = false;
      
      # Notebook settings
      "workbench.editorAssociations" = {
          "*.ipynb" = "jupyter-notebook";
      };
      "notebook.cellToolbarLocation" = {
          "default" = "right";
          "jupyter-notebook" = "left";
      };
      
      # Terminal settings
      "terminal.integrated.rendererType" = "dom";
      
      # Workbench settings
      "workbench.editor.highlightModifiedTabs" = true;
    };
  };
}
