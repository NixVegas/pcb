{
  lib,
  fetchFromGitHub,
  stdenv,
  makeWrapper,
  nodejs,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "JLC-FCTS-RE";
  version = "2024-05-25";

  src = fetchFromGitHub {
    owner = "Xerbo";
    repo = finalAttrs.pname;
    rev = "0bbfad72819aa60b26550204a9b4a88ed80da619";
    hash = "sha256-cmMBhgKiUVezoIgOtuP2akEKnPL3x143Q/jLvOgTFqw=";
  };

  patches = [ ./0001-Allow-custom-key-and-IV.patch ];

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/$pname
    cp decrypt.js encrypt.js $out/libexec/$pname/
    mkdir -p $out/bin

    makeWrapper ${lib.getExe nodejs} $out/bin/jlc-fcts-decrypt \
      --add-flag $out/libexec/$pname/decrypt.js
    makeWrapper ${lib.getExe nodejs} $out/bin/jlc-fcts-encrypt \
      --add-flag $out/libexec/$pname/encrypt.js

    runHook postInstall
  '';
})
