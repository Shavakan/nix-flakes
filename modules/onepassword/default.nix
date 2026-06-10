{ lib, pkgs, ... }:

{
  home.activation.install1PasswordApp =
    lib.hm.dag.entryAfter [ "setupLogging" "writeBoundary" ] ''
      src="${pkgs._1password-gui}/Applications/1Password.app"
      dst="/Applications/1Password.app"

      if [ -d "$src" ]; then
        $DRY_RUN_CMD rm -rf "$dst"
        $DRY_RUN_CMD /usr/bin/ditto "$src" "$dst"
        log_nix "onepassword" "Installed 1Password.app from ${pkgs._1password-gui}"
      else
        log_nix "onepassword" "Source bundle missing: $src"
      fi
    '';
}
