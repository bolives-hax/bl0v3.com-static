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

        mkSite = {name ? "bl0v3-website", url}: with pkgs; pkgs.stdenv.mkDerivation {
          inherit name;
          src = website-src;
          unpackPhase = ''
            cp -r --no-preserve=mode $src source
            cp -r --no-preserve=mode ${duckquill-theme} source/themes/duckquill
            cd source
            echo -e "# The URL the site will be built for\nbase_url = \"${url}\"\n" | cat - config.toml > config.toml
          '';
          buildPhase = ''
            ${pkgs.zola}/bin/zola build
          '';
          installPhase = ''
            cp -r public $out
          '';
        };
      in {
        packages = rec {
          default = github;
          github =  mkSite {
            name = "bl0v3-website-github";
            url = "https://bolives-hax.github.io";
          };
          bl0v3_dot_com = mkSite {
            name = "bl0v3-website-bl0v3_dot_com";
            url = "https://bl0v3.com";
          };
        };

        # type nix develop .#
        # and then in the shel you can use
        # zola serve OR zola build
        # NOTE that --base-url / --interface 0.0.0.0 --port $PORT are
        # needed for zola serve to work correctly 
        devShells.default = with pkgs; mkShell {
          buildInputs = [
            zola
          ];
        };
      }
    );
}

