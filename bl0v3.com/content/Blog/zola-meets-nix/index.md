+++
authors = ["bl0v3"]
title = "how I build this blog"
description = "Declarative build environments using nix plus the zola static site generator"
date = 2024-04-30
[taxonomies]
tags = ["nix", "zola", "blog","static site generator"]
[extra]

+++

If you read this very text its safe to assume you have come across my blog. This article
provides you with a little insight on how I created and manage it.

As if writing blogposts by itself wasn't hard enough, managing the build environment that ends
up generating these files you are viewing involves various other aspects to take care of as well.
As writing html/css by hand shouldn't exactly be the way to go on about specifically
maintaining a blog lets say (such as in my case). Its not unlikely that one has looked
at the various tools to essentially help you overcoming this burden. 

In my case I chose to employ a combination of
- git
- the [Zola]("https://getzola.org") static site generator
- nix

So what these tools essentially accomplish is:


Letting me create blogposts by creating a directory in
`/bl0v3.com/content/Blog/` such as `zola-meets-nix`
and then writing the actual posts by writing some markdown declarations into
`zola-meets-nix/index.md` lets say to generate the page you are currently viewing.

While so far all I have done is obtaining zolas source code and writing 
my blogposts into the respective markdown files. There is a actually little more to it as:

### What if I wanted to edit my blog from multiple machines and track changes?

While I could simply put my blog into a git repository like I've done [here](https://github.com/bolives-hax/bl0v3.com-static/tree/master) (Contains what you are currently viewing) there are things I wanted to take into account that wouldn't be
solved by simply doing that

Because I'd have to ensure that:
- the version of zola used across the machines I'm making edits from remains the
same
- That the build environment and dependencies used to build zola remain the same.

Also what if I wanted to host my blog on multiple platforms? For example at (bl0v3.com) or github.io. What if I maybe
want to make use of tools other than zola to create pages/the content found on these pages? Like maybe I'd like to
include some shaders compiled to webgl for interactive demos to reference in my blogposts. 

With each further component I can think of that I may want to include in the site generation at some point in the future.
The environment needed to create these posts would grow more and more complex. So I thought why not use [nix](https://nixos.org)
since I already use that on all of my workstations/laptops or serves or at this point even on my phone via [nix on droid](https://github.com/nix-community/nix-on-droid) or even [mobile-nixos (sorta experimental still)](https://mobile.nixos.org/).

Which is why the repo linked above contains [this](https://github.com/bolives-hax/bl0v3.com-static/blob/master/flake.nix)
**flake.nix** file. In essence this file defines the following function:

```nix
mkSite {name ? "bl0v3-website", url}
```

Which takes the arguments `name` _(which essentially just serves as a package name reference)_ and
`url` which would be the url to generate the site for. Thus the flake essentially outputs 2 _"derivations"_

```nix
{
  packages = rec {
    default = github;
    github =  mkSite {
      name ="bl0v3-website-github";
      url ="https://bolives-hax.github.io";
    };
    bl0v3_dot_com = mkSite {
      name ="bl0v3-website-bl0v3_dot_com";
      url ="https://bl0v3.com";
    };
  };
}
```

while I specify `name` by using the `?` operator which essentially allows assigning a default value in case `name` wasn't 
specified upon calling `mkSite{}`. `url` still needs to explicitly defined upon calling `mkSite`

The flakes input parameters are:

```nix
{
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
}
```

with `nixpkgs` providing the derivations/package definition for all packages contained within the `nixpkgs` package collection
_(which for example is where nixos gets its packages from. But due to nix's nature it works on a mac or non-nixos linux host just as well :3 since nix packages are pretty much build instructions rather than binary artifacts)_. `duckquill-theme` is the theme i use and `website-src`  provides the actual source for the markdown files and
config options used by zola. Additionally `flake-utils` provides some helpers (more on that later).

Thus all that is left is combining the flakes `inputs` and declarations to form the derivations passed via `outputs`:

```nix
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
        mkdir -p source/themes/
        cp -r --no-preserve=mode ${duckquill-theme} source/themes/duckquill
        cd source
        echo -e "# The URL the site will be built for\nbase_url = \"${url}\"" | cat - config.toml
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
        name =" bl0v3-website-github";
        url ="https://bolives-hax.github.io";
      };
      bl0v3_dot_com = mkSite {
        name =" bl0v3-website-bl0v3_dot_com";
        url ="https://bl0v3.com";
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
)
```

Let me break down this flake a little:

The `eachDefaultSystem` function called via
```nix
flake-utils.lib.eachDefaultSystem (system:
```
essentially generates an attribute set referencing the various platforms/architectures supported by nix/nixpkgs
by default _(nix also supports more obscure platforms such as riscv or i386 and has an excellent cross compilation infrastructure
but I reseve that topic for another blogpost that has yet to be written)_

This could be done by hand by specifying 
```nix
{
  outputs.packages = {
      x86_64-linux = "...";
      aarch64-linux = "...";
      x86_64-darwin = "...";
      # etc
      # ...
  };
}
```
manually but I like keeping things short, reduce code duplication and have a somewhat future proof setup as maybe
in the future another architecture gets adopted into said default architectures. Thus `eachDefaultSystem` essentially
merely generates these struct declaration prefixes and calls the function following `(system: ` which was written by me and
essentially generates the derivation containing the actual build instructions for the blog using the various urls.

Note that `system:` is passed as a function parameter and contains a string declaring the current system for which 
the attribute is being emitted. Thus the function within would essentially be called once with `x86_64-linux` and once 
with `x86_64-darwin` and so on.

```nix
mkSite {name,url}
```
ends up calling `pkgs.stdenv.mkDerivation` like:

```nix
pkgs.stdenv.mkDerivation {
  inherit name;
  src = website-src;
  unpackPhase = ''
    cp -r --no-preserve=mode $src source
    cp -r --no-preserve=mode ${duckquill-theme} source/themes/duckquill
    cd source
    echo -e "# The URL the site will be built for\nbase_url = \"${url}\"" | cat - config.toml
  '';
  buildPhase = ''
    ${pkgs.zola}/bin/zola build
  '';
  installPhase = ''
    cp -r public $out
  '';
}
```
which essentially runs the build process, places the output artifacts in the corresponding `/nix/store/`**<path>**
and inserts the url variable into the toml file referenced by zola. 

So putting together these components pretty much creates the basis for building my blog, while currently it doesn't really
account too much for the shortcomings listed above. Introducing more components into the website build process
is now easier than ever while also staying highly reproducible.

If I now wanted to serve that site on a nixos host trough nginx, generate certificates and so on all id have to do is something like:

```nix
{
  services.nginx = {
    enable = true;
    virtualHosts."blog.example.com" = {
      enableACME = true;
      forceSSL = true;
      root = "${bl0v3_website.packages.${system}.bl0v3_dot_com}";
    };
  };
  
  security.acme.certs = {
    "blog.example.com".email = "youremail@address.com";
  };
}
```

by adding it to a module declaration contained within **/etc/nixos** in the same sense other nixos options are being set.
Of course id need to provide the
`bl0v3_website` definition thats being referenced in
```nix
{
    root = "${bl0v3_website.packages.${system}.bl0v3_dot_com}";
}
```
though thats relatively simple by adding it to my flake inputs or using `fetchGit` on non flake
systems. _(there are very valid reasons one would not want to use flakes but by the time these start to
be a concern, you most likely be aware of them already. Otherwise I'd say its fine to use flakes
as they do also solve certain issues. In the end its just personal preference)_
```nix
{
  inputs = {
    bl0v3_static = {
      url = "github:bolives-hax/bl0v3.com-static";
    };
  };
}
```

To populate the github.io repo I do something like:

```nix
{
  inputs = {
    bl0v3_static = {
      url = "github:bolives-hax/bl0v3.com-static";
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {self,bl0v3_static,flake-utils,nixpkgs}: flake-utils.lib.eachDefaultSystem(system: 
  let
    pkgs = import nixpkgs {inherit system;};
  in {
    packages.default = pkgs.writeShellScriptBin "update-site" ''
      SITE_PATH="${bl0v3_static.packages.${system}.github}"
      echo $SITE_PATH
      if [ -z "$1" ]; then
        echo usage: nix run .# \"git commit message\"
      else 
      cp -Lr --no-preserve=mode $SITE_PATH site
      cp -r .git flake.nix README.md site/
      cd site
      git add .
      git commit -m \"$1\"
      git push
      cd ../
      rm -rf site
      fi
    '';
  });
}
```

while thats a little hacky it gets the job done for now but I plan take a different approach either way making use of my
CI infrastructure  but for now this gets the job done as all id have to do to populate/update that site is run:

```bash
nix run .# "commit-message"
```
after cloning [this repository](https://github.com/bolives-hax/bolives-hax.github.io/tree/master) but ofc that should be
automated eventually and be part of my nix powered CI/CD.

