{
  description = "Fetch derivations from your friends.";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    branding = {
      url = "github:NixOS/branding";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      branding,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
      ];

      flake = {
      };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        {
          config,
          system,
          inputs',
          pkgs,
          final,
          lib,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.default
            ];
            config = { };
          };

          overlayAttrs = {
            inherit (branding.legacyPackages.${system}) nixos-branding;
            kicad-text-injector = pkgs.callPackage ./pkgs/kicad-text-injector { };
            jlc-fcts-re = pkgs.callPackage ./pkgs/jlc-fcts-re { };
          };

          devShells.default = pkgs.mkShell {
            name = "nixvegas-badge-dev";
            packages = with pkgs; [
              kicad
              gerbv
              inkscape
              kicad-text-injector
              jlc-fcts-re
            ];
          };

          packages.default = pkgs.callPackage ./. { };
        };
    };
}
