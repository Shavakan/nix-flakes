{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.awsctx;

  # awsctx stores config under XDG dirs; on Darwin these are macOS-specific.
  # Match the convention used by `bin/aws-login-all` in upstream awsctx.
  configDir =
    if pkgs.stdenv.isDarwin
    then "${config.home.homeDirectory}/Library/Application Support/awsctx"
    else "${config.xdg.configHome}/awsctx";
in
{
  options.services.awsctx = {
    enable = mkEnableOption "awsctx AWS profile context switcher";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.awsctx
      pkgs.saml2aws
    ];

    # Source the awsctx bash function in zsh (works because no bashisms in awsctx()).
    # bashcompinit is needed so `complete -F` from the script doesn't error.
    programs.zsh.initContent = mkAfter ''
      autoload -Uz bashcompinit && bashcompinit
      source ${pkgs.awsctx}/share/awsctx/awsctx.sh
    '';

    programs.bash.initExtra = mkAfter ''
      source ${pkgs.awsctx}/share/awsctx/awsctx.sh
    '';

    # Mirror the upstream-shipped profiles into the user's awsctx config dir
    # so `awsctx <ctx>` finds `${configDir}/<ctx>.config`.
    home.activation.setupAwsctxProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      log_nix "awsctx" "Syncing profiles into ${configDir}"
      mkdir -p "${configDir}"
      if [ -d "${pkgs.awsctx}/share/awsctx/profiles" ]; then
        for src in "${pkgs.awsctx}/share/awsctx/profiles"/*.config; do
          [ -e "$src" ] || continue
          install -m644 "$src" "${configDir}/$(basename "$src")"
        done
      fi
    '';
  };
}
