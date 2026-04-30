{ lib
, stdenvNoCC
, makeWrapper
, bash
, saml2aws
, coreutils
, findutils
, gnugrep
, src
}:

stdenvNoCC.mkDerivation {
  pname = "awsctx";
  version = "unstable-2026-02-24";

  inherit src;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin \
             $out/share/awsctx \
             $out/share/awsctx/profiles \
             $out/share/fish/vendor_completions.d \
             $out/share/fish/vendor_functions.d \
             $out/share/fish/vendor_conf.d

    install -m755 bin/aws-login-all $out/bin/aws-login-all

    install -m644 shells/bash/awsctx.sh $out/share/awsctx/awsctx.sh

    install -m644 shells/fish/functions/awsctx.fish \
      $out/share/fish/vendor_functions.d/awsctx.fish
    install -m644 shells/fish/completions/awsctx.fish \
      $out/share/fish/vendor_completions.d/awsctx.fish

    if [ -d prompts/tide/conf.d ]; then
      install -m644 prompts/tide/conf.d/*.fish $out/share/fish/vendor_conf.d/
    fi
    if [ -d prompts/tide/functions ]; then
      install -m644 prompts/tide/functions/*.fish $out/share/fish/vendor_functions.d/
    fi

    if [ -d profiles ]; then
      cp -r profiles/. $out/share/awsctx/profiles/
    fi

    wrapProgram $out/bin/aws-login-all \
      --prefix PATH : ${lib.makeBinPath [ saml2aws coreutils findutils gnugrep ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "AWS profile context switcher (devsisters)";
    homepage = "https://github.com/devsisters/awsctx";
    platforms = platforms.unix;
    mainProgram = "aws-login-all";
  };
}
