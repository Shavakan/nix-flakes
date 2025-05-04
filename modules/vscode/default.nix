{ config, lib, pkgs, ... }:

{
  imports = [
    ./extensions.nix
    ./settings.nix
  ];

  programs.vscode = {
    enable = true;

    # New structure uses mutableExtensionsDir differently
    # With profiles, we need to use the new structure
    mutableExtensionsDir = false;

    # Update checks are now under profiles.default
    profiles.default = {
      # Disable update checks (we'll manage updates through Nix)
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;

      # Keybindings
      keybindings = [
        {
          key = "ctrl+shift+c";
          command = "editor.action.commentLine";
          when = "editorTextFocus && !editorReadonly";
        }
        {
          key = "alt+up";
          command = "editor.action.moveLinesUpAction";
          when = "editorTextFocus && !editorReadonly";
        }
        {
          key = "alt+down";
          command = "editor.action.moveLinesDownAction";
          when = "editorTextFocus && !editorReadonly";
        }
      ];
    };
  };
}
