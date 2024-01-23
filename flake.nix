{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nix-ocaml/nix-overlays";

    castore-src = {
      url = "github:leostera/castore";
      flake = false;
    };

    blink-src = {
      url = "github:leostera/blink";
      flake = false;
    };

    trail-src = {
      url = "github:leostera/trail";
      flake = false;
    };

    nomad-src = {
      url = "github:leostera/nomad";
      flake = false;
    };

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

    atacama-src = {
      url = "github:leostera/atacama";
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
          propagatedBuildInputs = [ tty ];
        };

        spices = pkgs'.ocamlPackages.buildDunePackage {
          pname = "spices";
          version = "2.0";
          src = inputs.minttea-src;
          propagatedBuildInputs = [ colors ];
        };

        trail = pkgs'.ocamlPackages.buildDunePackage {
          pname = "trail";
          version = "2.0";
          src = inputs.trail-src;
          propagatedBuildInputs = [
            pkgs'.ocamlPackages.httpaf
            pkgs'.ocamlPackages.ppx_bitstring
            pkgs'.ocamlPackages.http
            pkgs'.ocamlPackages.uuidm
            pkgs'.ocamlPackages.ptime
            pkgs'.ocamlPackages.calendar
            pkgs'.ocamlPackages.bitstring
            telemetry
            atacama
            bytestring
          ];
        };

        config = pkgs'.ocamlPackages.buildDunePackage {
          pname = "config";
          version = "2.0";
          src = inputs.config-src;
          propagatedBuildInputs = [ pkgs'.ocamlPackages.sedlex spices ];
        };

        libuc = pkgs'.ocamlPackages.buildDunePackage {
          pname = "libc";
          version = "2.0";
          src = inputs.libcml-src;
          propagatedBuildInputs = [ config pkgs'.ocamlPackages.ppxlib spices ];
        };

        io = pkgs'.ocamlPackages.buildDunePackage {
          pname = "io";
          version = "2.0";
          src = inputs.riot-src;
          propagatedBuildInputs = [ pkgs'.ocamlPackages.cstruct ];
        };

        bytestring = pkgs'.ocamlPackages.buildDunePackage {
          pname = "bytestring";
          version = "2.0";
          src = inputs.riot-src;
          propagatedBuildInputs = [ libuc io ];
        };

        gluon = pkgs'.ocamlPackages.buildDunePackage {
          pname = "gluon";
          version = "2.0";
          src = inputs.riot-src;
          propagatedBuildInputs = [ pkgs'.ocamlPackages.uri libuc bytestring ];
        };

        atacama = pkgs'.ocamlPackages.buildDunePackage {
          pname = "atacama";
          version = "2.0";
          src = inputs.atacama-src;
          propagatedBuildInputs = [
            telemetry
            rito
            bytestring
            pkgs'.ocamlPackages.tls
            pkgs'.ocamlPackages.mtime
            gluon
          ];
        };

        rito = pkgs'.ocamlPackages.buildDunePackage {
          pname = "riot";
          version = "2.0";
          src = inputs.riot-src;
          propagatedBuildInputs = [
            gluon
            io
            telemetry
            pkgs'.ocamlPackages.hmap
            pkgs'.ocamlPackages.ptime
            pkgs'.ocamlPackages.mtime
            pkgs'.ocamlPackages.tls
          ];
        };

        nomad = pkgs'.ocamlPackages.buildDunePackage {
          pname = "nomad";
          version = "2.0";
          src = inputs.nomad-src;
          buildInputs = [
            rito
            pkgs'.ocamlPackages.ppx_bitstring
            bytestring
            pkgs'.ocamlPackages.decompress
            pkgs'.ocamlPackages.digestif
            pkgs'.ocamlPackages.http
            pkgs'.ocamlPackages.bitstring
            telemetry
            atacama
            trail
          ];
        };

        blink = pkgs'.ocamlPackages.buildDunePackage {
          pname = "blink";
          version = "2.0";
          src = inputs.blink-src;
          propagatedBuildInputs = (with pkgs'.ocamlPackages; [
            mirage-crypto-rng
            httpaf
            x509
            tls
            angstrom
            faraday
            cohttp
          ]) ++ [ castore rito];
        };

        castore = pkgs'.ocamlPackages.buildDunePackage {
          pname = "castore";
          version = "2.0";
          src = inputs.castore-src;
          buildInputs = (with pkgs'.ocamlPackages; [ ]);
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

          buildInputs = (with pkgs'.ocamlPackages; [
            utop
            rito
            nomad
            trail
            decompress
            digestif
            mirage-crypto-rng
            angstrom
            blink
            cohttp
            yojson
          ]);
        };

        formatter = pkgs.nixfmt;
      });
}
