{
  description = "Nix flake for building my website+blog bl0v3.com";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url  = "github:numtide/flake-utils";
    website-src = {
      flake = false;
      url = "path:bl0v3.com";
    };
    duckquill-theme = {
      type = "git";
      flake = false;
      url = "https://codeberg.org/daudix/duckquill.git";
    };
  };

  outputs = { self, nixpkgs, flake-utils, website-src, duckquill-theme}:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        packages.default = with pkgs; pkgs.stdenv.mkDerivation {
            name = "bl0v3-website";
            src = website-src;
            #phases = [ "buildPhase" "installPhase" ];
            #sourceRoot = "${src}/bl0v3.com";
            # TODO remove the need for these chmods
            unpackPhase = ''
              cp -r --no-preserve=mode $src source
              cp -r --no-preserve=mode ${duckquill-theme} source/themes/duckquill
              cd source
            '';
            buildPhase = ''
              ${pkgs.zola}/bin/zola build
            '';
            installPhase = ''
              cp -r public $out
            '';
          };

        # type nix develop .#
        # and then in the shel you can use
        # zola serve OR zola build
        devShells.default = with pkgs; mkShell {
          buildInputs = [
            zola
          ];

          #shellHook = ''
          #'';
        };
      }
    );
}

