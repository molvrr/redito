{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nix-ocaml/nix-overlays";

    riot-src = {
      url = "github:leostera/riot";
      flake = false;
    };

    libcml-src = {
      url = "github:leostera/libc.ml";
      flake = false;
    };

    config-src = {
      url = "github:leostera/config.ml";
      flake = false;
    };

    minttea-src = {
      url = "github:leostera/minttea";
      flake = false;
    };

    colors-src = {
      url = "github:leostera/colors";
      flake = false;
    };

    tty-src = {
      url = "github:leostera/tty";
      flake = false;
    };

    telemetry-src = {
      url = "github:leostera/telemetry";
      flake = false;
    };

  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
          (self: super: { ocamlPackages = super.ocaml-ng.ocamlPackages_5_1; })
        ];

        pkgs' = pkgs.pkgsCross.musl64;

        telemetry = pkgs'.ocamlPackages.buildDunePackage {
          pname = "telemetry";
          version = "2.0";
          src = inputs.telemetry-src;
        };

        tty = pkgs'.ocamlPackages.buildDunePackage {
          pname = "tty";
          version = "2.0";
          src = inputs.tty-src;
          propagatedBuildInputs = with pkgs'.ocamlPackages; [ uutf ];
        };

        colors = pkgs'.ocamlPackages.buildDunePackage {
          pname = "colors";
          version = "2.0";
          src = inputs.colors-src;
          buildInputs = [ tty pkgs'.ocamlPackages.uutf ];
        };

        spices = pkgs'.ocamlPackages.buildDunePackage {
          pname = "spices";
          version = "2.0";
          src = inputs.minttea-src;
          buildInputs = [ pkgs'.ocamlPackages.uutf ];
          propagatedBuildInputs = [ colors tty ];
        };

        config = pkgs'.ocamlPackages.buildDunePackage {
          pname = "config";
          version = "2.0";
          src = inputs.config-src;
          buildInputs = [ spices colors tty ];
          propagatedBuildInputs = [ pkgs'.ocamlPackages.sedlex ];
        };

        libuc = pkgs'.ocamlPackages.buildDunePackage {
          pname = "libc";
          version = "2.0";
          src = inputs.libcml-src;
          buildInputs = [ config pkgs'.ocamlPackages.ppxlib spices ];
        };

        rio = pkgs'.ocamlPackages.buildDunePackage {
          pname = "rio";
          version = "2.0";
          src = inputs.riot-src;
          buildInputs = [ pkgs'.ocamlPackages.cstruct ];
        };

        bytestring = pkgs'.ocamlPackages.buildDunePackage {
          pname = "bytestring";
          version = "2.0";
          src = inputs.riot-src;
          buildInputs = [
            libuc
            rio
            pkgs'.ocamlPackages.ppxlib
          ];

          propagatedBuildInputs = [
            pkgs'.ocamlPackages.cstruct
            pkgs'.ocamlPackages.sedlex
            pkgs'.ocamlPackages.uutf
            rio
            spices
          ];
        };

        gluon = pkgs'.ocamlPackages.buildDunePackage {
          pname = "gluon";
          version = "2.0";
          src = inputs.riot-src;
          buildInputs = [
            pkgs'.ocamlPackages.uri
            pkgs'.ocamlPackages.ppxlib
            pkgs'.ocamlPackages.cstruct
            bytestring
            spices
            config
          ];
          propagatedBuildInputs = [ libuc pkgs'.ocamlPackages.uri ];
        };

        rito = pkgs'.ocamlPackages.buildDunePackage {
          pname = "riot";
          version = "2.0";
          src = inputs.riot-src;
          buildInputs =
            [ rio pkgs'.ocamlPackages.hmap pkgs'.ocamlPackages.ptime ];
          propagatedBuildInputs = [
            pkgs'.ocamlPackages.mtime
            pkgs'.ocamlPackages.mirage-crypto-rng
            pkgs'.ocamlPackages.randomconv
            pkgs'.ocamlPackages.tls
            bytestring
            gluon
            telemetry
          ];
        };

      in {
        devShells.default = pkgs'.mkShell rec {
          nativeBuildInputs = with pkgs'.ocamlPackages; [
            dune_3
            findlib
            ocaml
            ocaml-lsp
            ocamlformat
          ];

          buildInputs = (with pkgs'.ocamlPackages; [ utop rito ]);
        };

        formatter = pkgs.nixfmt;
      });
}
