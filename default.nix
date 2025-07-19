{
  lib,
  fetchzip,
  stdenvNoCC,
  kicad,
  python3,
  jq,
  moreutils,
  nixos-branding,
  inkscape,
  jlc-fcts-re,
  kicad-text-injector,
  pngcrush,
  imagemagick,
  zip,
  unzip,

  version,
  versionCode,
}:

let
  jlcPcbKicadLibrary = fetchzip rec {
    version = "2025.07.12";
    name = "JLCPCB-KiCad-Library-${version}.zip";
    url = "https://github.com/CDFER/JLCPCB-Kicad-Library/releases/download/${version}/${name}";
    stripRoot = false;
    hash = "sha256-SrRr7RKCWSCgQAX+BG4XXNYGAr5ek2EZEvWQ6e/HZww=";
  };

  fabricationToolkit = fetchzip rec {
    version = "5.1.0";
    name = "JLC-Plugin-for-KiCad-${version}.zip";
    url = "https://github.com/bennymeg/Fabrication-Toolkit/releases/download/${version}/${name}";
    stripRoot = false;
    hash = "sha256-oGRlpzRavKPsV2wMRgh9B3qUOWgsZkQ84PrRp11n+Gw=";
  };

  kicad3rdparty = stdenvNoCC.mkDerivation {
    name = "kicad-3rdparty";

    nativeBuildInputs = [ jq ];

    sourceRoot = ".";

    srcs = [ jlcPcbKicadLibrary fabricationToolkit ];

    outputs = [ "out" "config" ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out $config

      packages='{"packages": []}'
      for plugin in $srcs; do
        package_id="$(jq -r '.identifier | gsub("\\."; "_")' < "$plugin/metadata.json")"
        for dir in $plugin/*; do
          if [ -d "$dir" ]; then
            mkdir -p "$out/$(basename -- "$dir")"
            ln -vs "$dir" "$out/$(basename -- "$dir")/$package_id"
          fi
        done
        packages="$(echo "$packages" | jq -r '. as $val | $val.packages += [{current_version: $plugin.versions[0].version, install_timestamp: 0, package: $plugin}]' \
          --argjson plugin "$(<$plugin/metadata.json)")"
      done

      echo "$packages" | jq "." | tee $config/installed_packages.json

      runHook postInstall
    '';
  };

  kicadPython3 = python3.withPackages (ps: [ ps.wxpython ps.kicad ]);

  nixosLogoPng = stdenvNoCC.mkDerivation (finalAttrs: {
    name = "${finalAttrs.logo.name}.png";

    logo = nixos-branding.artifacts.internal.nixos-logomark-default-gradient-none;

    dontUnpack = true;

    nativeBuildInputs = [
      inkscape
      pngcrush
    ];

    buildPhase = ''
      runHook preBuild
      HOME="$(pwd)" inkscape --export-background=transparent --export-background-opacity=0 -w 4096 -o $name \
        $logo/*.svg
      pngcrush -brute -rem alla -ow $name
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mv $name $out
      runHook postInstall
    '';
  });
in
stdenvNoCC.mkDerivation {
  pname = "nix-badge";
  inherit version versionCode;

  src = ./kicad;

  inherit nixosLogoPng;

  nativeBuildInputs = [
    kicad
    kicadPython3
    moreutils
    imagemagick
    jlc-fcts-re
    kicad-text-injector
    zip
    unzip
  ];

  layers = [
    "F.Cu"
    "B.Cu"
    "F.Paste"
    "B.Paste"
    "F.Silkscreen"
    "B.Silkscreen"
    "F.Mask"
    "B.Mask"
    "Edge.Cuts"
  ];

  outputs = [ "out" "check" "fab" "render" ];

  configurePhase = ''
    runHook preConfigure

    export HOME="$(pwd)"
    export KICAD_VERSION="${lib.versions.majorMinor kicad.version}"
    _3rdparty=$HOME/.local/share/kicad/$KICAD_VERSION/3rdparty
    config=$HOME/.config/kicad/$KICAD_VERSION

    mkdir -p "$(dirname -- "$_3rdparty")" "$config"
    ln -s ${kicad3rdparty.out} "$_3rdparty"
    for file in ${kicad3rdparty.config}/*; do
      cp --no-preserve=mode "$file" "$config/"
    done

    kicad-text-injector -e -i nixos.kicad_pcb | sponge nixos.kicad_pcb

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    fake_easyeda() {
      find "$1" -type f -print -exec \
        sed -Ei 's/^G04 Created by KiCad.*$/G04 EasyEDA Pro v2.2.40.3, 2025-07-17 00:11:30/g' {} \;
    }

    mkdir -p gerbers
    kicad-cli pcb export gerbers --output gerbers \
      --layers "$(echo "$layers" | tr ' ' ',')" \
      --subtract-soldermask \
      nixos.kicad_pcb
    kicad-cli pcb export drill --output gerbers \
      --generate-map --map-format gerberx2 \
      nixos.kicad_pcb

    fake_easyeda gerbers

    front_silkscreen=Fabrication_ColorfulTopSilkscreen.FCTS
    back_silkscreen=Fabrication_ColorfulBottomSilkscreen.FCBS
    outline_silkscreen=Fabrication_ColorfulBoardOutlineLayer.FCBO

    substituteInPlace jlc-front.svg \
      --replace-fail '@width@' "$(identify -format '%w' $nixosLogoPng)" \
      --replace-fail '@height@' "$(identify -format '%h' $nixosLogoPng)" \
      --replace-fail '@png@' "$(base64 -w0 < $nixosLogoPng)"
    jlc-fcts-encrypt jlc-front.svg gerbers/$front_silkscreen
    jlc-fcts-encrypt jlc-back.svg gerbers/$back_silkscreen
    jlc-fcts-encrypt jlc-outline.svg gerbers/$outline_silkscreen

    jlc_plugin="$(echo $_3rdparty/plugins/*JLC-Plugin*)"
    PYTHONPATH="$(dirname -- "$jlc_plugin")" python -m "$(basename -- "$jlc_plugin").cli" -p nixos.kicad_pcb

    zip_name="$(basename -- production/*.zip)"
    (cd gerbers && zip -uv "../production/$zip_name" $front_silkscreen $back_silkscreen $outline_silkscreen)

    mkdir -p production/zip
    (
      cd production/zip
      unzip "../$zip_name"
      rm -f "../$zip_name"
      fake_easyeda .
      zip -r9 "../$zip_name" .
    )
    rm -rf production/zip

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    kicad-cli sch erc --output erc.report \
      --severity-error --exit-code-violations \
      nixos.kicad_sch || { cat erc.report >&2 && exit 1; }
    cat erc.report >&2
    kicad-cli pcb drc --output drc.report \
      --schematic-parity --severity-error --exit-code-violations \
      nixos.kicad_pcb || { cat drc.report >&2 && exit 1; }
    cat drc.report >&2

    runHook postCheck
  '';

  postCheck = ''
    args=(--width 2048 --height 2048 --quality high --perspective nixos.kicad_pcb)

    mkdir -p render
    kicad-cli pcb render --side top --output render/top.png "''${args[@]}"
    kicad-cli pcb render --side bottom --output render/bottom.png "''${args[@]}"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out $check $fab $render
    mv *.report $check
    mv gerbers/* $out/
    mv production/* $fab/
    mv render/* $render/

    runHook postInstall
  '';
}
