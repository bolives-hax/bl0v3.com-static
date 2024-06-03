+++
authors = ["bl0v3"]
title = "making use of dyalog APL's isolates+futures in the the apl raymarcher"
description = "bringing dyalogs isolates and futures to the apl raymarcher"
date = 2024-05-02
[taxonomies]
tags = ["APL", "dyalog", "isolates", "parallelEach", "multi-threading", "demo", "raymarching", "3D Graphics", "dyalog", "math"]
[extra]
trigger  = """
skip to the "actual implementation" headline/section if you aren't interesting in the nix specific issues 
that had to be overcome in order to get dyalog-apl running along with futures and isolates
"""
+++

# overcoming nix specific issues to get isolates and futures to work

**(skip to "actual implementation" below if this this isn't of any interest to you)**

Unlike I initially assumed just importing the isolate workspace on dyalog-apl retrived trough nix's
nixpkgs ( as I used that to produce these builds in a reproducible/declarative fashion) wasn't
directly feasible as upon loading the workspace I'd get some quite strange errors. Upon further
debugging this issue I came to the conclusion that it was caused by the nix derivation for dyalog-apl
rather than dyalog apl itself.

So after opening an issue and notifying the package maintainer 
at [dyalog: isolates (parallel forEach and co) appear to be broken #316439](https://github.com/NixOS/nixpkgs/issues/316439) it seems as if they managed to fix it
via [dyalog: also apply patchelf to dyalog.rt #316495](https://github.com/NixOS/nixpkgs/pull/316495)

The issue basically boils down to the following:

As nix stores all binaries/libraries in `/nix/store/<hash>-<path>` packaging binary executables can
be a litty funny at times.  As obtaining the source code for dyalog-apl isn't possible as for now
were forced to work with the .deb/.rpm etc packages they provide. Which is exactly what the nix
expression linked above does.

But just copying the contents of that .deb to /bin and /lib respectively isn't all there is to it sadly
as binary packages already have pre defined [ELF headers](https://en.m.wikipedia.org/wiki/Executable_and_Linkable_Format) these make assumptions about the names and locations of the library components to be loaded
upon executing the elf by the linux kernel.

like mentioned in the issue the maintainer forgot to also add ncurses to `dyalog.rt`
luckily as the elf specification is simple enough

{{ image(url="https://raw.githubusercontent.com/corkami/pics/master/binary/elf101/elf101.svg") }}

to alter using tools such as `patchelf`, which is very frequently seen when packaging binary packages
for nix/nixos.

Thus everything required to do was changing
```bash
patchelf ${dyalogHome}/dyalog --add-needed libncurses.so
```

to

```bash
for exec in "dyalog" "dyalog.rt"; do
     patchelf ${dyalogHome}/$exec --add-needed libncurses.so
done
```
within the nix expression. Which the maintainer did an awesome job of figuring out [see](https://github.com/NixOS/nixpkgs/pull/316495/commits/0ea7fe9f11803bea5fd9f6b2ecd96fd96b0731e7)

Thus using the package with the previous expression running ldd would result in
```
linux-vdso.so.1 (0x00007ffff7fc6000)
libm.so.6 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libm.so.6 (0x00007ffff7edd000)
libpthread.so.0 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libpthread.so.0 (0x00007ffff7ed8000)
libdl.so.2 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libdl.so.2 (0x00007ffff7ed3000)
libc.so.6 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libc.so.6 (0x00007ffff7213000)
/nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/ld-linux-x86-64.so.2 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib64/ld-linux-x86-64.so.2 (0x00007ffff7fc8000)
```

while using the fixed drv with ncurses being added to the elf header would result in

```
linux-vdso.so.1 (0x00007ffff7fc6000)
libncurses.so => /nix/store/zcjy82jk8i8y1cvvzaadj5wiz41gvp53-ncurses-abi5-compat-6.4/lib/libncurses.so (0x00007ffff7f58000)
libm.so.6 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libm.so.6 (0x00007ffff7e75000)
libpthread.so.0 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libpthread.so.0 (0x00007ffff7e70000)
libdl.so.2 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libdl.so.2 (0x00007ffff7e6b000)
libc.so.6 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/libc.so.6 (0x00007ffff7213000)
/nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib/ld-linux-x86-64.so.2 => /nix/store/k7zgvzp2r31zkg9xqgjim7mbknryv6bs-glibc-2.39-52/lib64/ld-linux-x86-64.so.2 (0x00007ffff7fc8000)
```

note `libncurses.so => /nix/store/zcjy82jk8i8y1cvvzaadj5wiz41gvp53-ncurses-abi5-compat-6.4/lib/libncurses.so (0x00007ffff7f58000)` being present now after applying the fix

So until that PR/commit is merged into nixpkgs I'd have to specify:

```nix
{
  inputs = {
    nixpkgs = {
      url = "https://github.com/TomaSajt/nixpkgs.git";
      type = "git";
      rev = "0ea7fe9f11803bea5fd9f6b2ecd96fd96b0731e7";
    };
    # other inputs ...
  };
}
```
within my flake.nix expression used to build this project. If you aren't using nix but the rpm/deb
package youd of course not have to do this.


Another approach of solving this issue would be using [buildFHSEnv](https://ryantm.github.io/nixpkgs/builders/special/fhs-environments/)
which I would have done if me or the maintainers couldn't figure out how to fix this
in time. 

As _buildFHS env uses Linux' namespaces feature to create temporary lightweight environments which are destroyed after all child processes exit, without requiring elevated privileges. It works similar to containerisation technology such as Docker or FlatPak but provides no security-relevant separation from the host system_

this implies the presence of a namespace enabled linux kernel which would break nix's excellent
macos/darwin support as well as nix on non namespace enabled linux systems. So in order to keep
the majority of nixpkgs functional on macos and non-nixos systems
_(by the way nix is availible in the debian/arch repos by default)_  patchelf is generally to be favored.
But in especially nasty cases such as where precompiled (e.g nonfree packages such as steam lets say) 
packages are expecting certain binaries or files in general to be present in **/sbin/** , **/bin/** or
**/usr/bin** and the files are sourced at runtime rather than via the elf header upon program load.
buildFHS would have to be used as thats a better approach than trying to binary-patch the hardcoded
references within the compiled software.


# actual implementation 

Since [this commit](https://github.com/bolives-hax/apl-raymarcher/commit/ddde091fa2cb4c635cc6a1e39a2f4f6183852317) multithreading is now availible



While at the time of writing this the amount of theads is hardcoded via `threads←4` in flake.nix but you are free to changing
the amount of threads by either altering the `raymarcher.apl` file or the flake.nix file accordingly (see flake.nix to see what variables need to be applied).
Thus rendering with much more than 4 threads is totally feasible and it does seem to be able to truly utilize all resources given to it perfectly fine.

See (rendering in 4K):

{{ image(url="https://github.com/bolives-hax/apl-raymarcher/blob/master/multithread-showcase.jpg?raw=true") }}



(TODO actually explain how this was pulled off. Until then check `raymarcher.apl`'s comments that were added in the commit linked above
