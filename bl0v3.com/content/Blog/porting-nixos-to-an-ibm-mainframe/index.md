
+++
authors = ["bl0v3"]
title = "Porting NixOS to IBM mainframes"
description = "Well as if id know the reason"
date = 2025-01-01
[taxonomies]
tags = [ "NixOS", "mainframe", "s390x", "linux", "linux on Z", "linuxone(TODO)", "qemu", "emulators", "long" ]
[extra]
disclaimer = """
# **THIS IS STILL UNDER CONSTRUCTION | WORK IN PROGRESS**
While I am confident that taking the path I took does work. It needs to be said
that I am very sure that its neither the most efficent one and that all assumptions made
are accurate/correct.
"""
trigger  = """
Sections of this article are written in a way that **prioritize describing the journey rather than the result**
directly. Which means that this takes place from **my perspective**. Im essentially trying to tell
a story so:

**So please do not expect some sort of quick reference for common pitfalls**
I decided for this style of writing/explaining the issue as I feel like
there really ain't too much need tor a plain reference especially
not for something that most likely very few people will ever require. The
chance of whomever reading this ending up in my situation is so slim
that in that case im sure they wouldn't mind reading this and not getting
a quick reference _(plus they will know what awaits them)_**

This article is not trying to be correct about everything brought up.
It merely serves the purpose of **documenting how I did this**. While I'm definitively willing to
accept critique please keep in mind that the primary purpose of
this article is to **describe the process I underwent** to get here.

If you rely on fully accurate information you sadly will have to do your
own research to back up my claims or find them to be false
"""
+++

{{ image(url="TODO.jpg", alt="todo_mainframe_and_nix_logo.jpg", no_hover=true) }}

**TODOS:**
- link to neofetch software about.txt or sth
- maybe include a picture of the neofetch
- show how to make containers/tarballs without kernel
- show how to run nixos-install 
- show how the iso thing works
- at some point mention that "lol emulators cool but you will see
that they aint the same shit" (dasd ccwgroup)
- show like an abstract from real mainframe configuration (the one on paper)
and how to write them in hercules

# What does this article address?

Like said previously this article documents part of the process I underwent
to get NixOS running on IBM's mainframe architecture. 

While it obviously is somewhat focused on the s390x/Z architecture. A few
concepts/technologies/tricks found here can of course be either partially
or fully applied to the process on other architectures. These roughly are the
points covered:

**TODO clean up, order correctly, give enough insight up here to let
people wishing to only look at a specific section find it**

-all

-the

-bootstrap

-shit

**TODO sum divider**

kernel/os/boot ... etc ... shit:

- cross compiling a nixos rootfs tarball and booting this up **TODO maybe also test binfmt**
- alpine kexec
- building iso
- zipl (usage , packaging and linker section fun)
- qemu ( focus on differences in hw)
- getting nix to run on alpine
- installing nixos without nixos
- bootstrap process
- various obscure package fixes
- cross compilation of nixos systems

{% alert(note=true) %}
This article may be perceived as rather long. Keep in mind that it does
cover quite a few things not all of these are essential.
{% end %}

{% alert(important=true) %}
Some sections are specific to problems I faced due to the setup
I was doing this in and other than *oh hey I didn't know that* may
not really provide you with a lot of actually relevant information.
{% end %}

# The situation: 

Well where do I start ... I'm not even quite sure anymore what motivated me to give this a shot but it more or less boils down to
these 3 points:

- a mainframe somehow managed to appear in front of me ... <small>(I guess that doesn't happen too often)</small>
{{ image(url="https://files.catbox.moe/7qze3s.jpg", alt="me with a mainframe", no_hover=true) }}

- I wanted to add a platform to Nix(OS) and see how things work *"from the ground up"* <small>(but nearly everything was already added even risc-v)</small>

 I thought it would be funny to use it to post in in some sort of desktop thread with this <small>but lying ain't cool
 and it actually running there may make it even more funny (or at least I thought so)</small>
{{ image(url="https://files.catbox.moe/v08l22.jpg", alt="first_neofetch_s390x_showcase_screencap", no_hover=true) }}


I quickly came to the realisation that unlike initially assumed "just running NixOS" (and consequently neofetch) wasn't as simple as I thought it would be as:

- there are no premade s390x isos/containers/...

- not even the bootstrap tools were available *(thus no `pkgs.stdenv {}`)*

- [s390(x)](https://en.wikipedia.org/wiki/IBM_System/390)/[z/Architecture](https://en.wikipedia.org/wiki/Z/Architecture) is an [big endian](https://en.wikipedia.org/wiki/Endianness) architecture

- emulators([binfmt](https://en.wikipedia.org/wiki/Binfmt_misc)) are not only broken
but also insanely slow and don't scale too well across multiple threads/cores

- cross compilation is a pain but you somehow need to build some sort of bootstrap/dev system before you can actually run/build 
things on s390x itself. <small>(as nobody bothered to build them before)</small>

Though with the help of various people (folks working at IBM , friends and a bunch of people involved with NixOS). A little patience and
having spend your teenage years running linux on various cursed platforms ..... these challenges were overcome :D

## where to start?

In order to get things running on an s390x host you obviously need to compile your software for the
s390x architecture/target. So you either:

- run your compiler/buildenv natively 
<small>(this assumes that you have these already for the s390x architecture)</small> but as we don't have
these we can't.

- you cross-compile from another architecture such as x86 <small>(this did partially work but
is known to cause issues in general)</small>

**TODO: include a small showcase on how to cross compile things on nix**

One of the things that makes cross compiling rather hard is that you can't really
execute the binaries you just build. This usually is not a problem and to some degree
nix even accounts for this.

**TODO explain how nix differenciates various buildInputs =        specifications**.

Sadly at times there is software that **(often even independently of nix!)** is either very hard to cross compile
OR upright not designed to <small>( ... like `zipl` the bootloader we gonna have to use eventually)</small>.
Thus unless we get native compilation working we can use "*the next best thing*":

#### getting a non s390x NixOS host to run s390x binaries:

I expected this to work out of the box but it didn't, luckily the issue was easy to overcome 
and this ended up being a rather quick fix: [added s390x option type via magic attributes #327665](https://github.com/NixOS/nixpkgs/pull/327665).

As all that had to be done was more or less
adding the [magic extension sequence](https://github.com/qemu/qemu/blob/b69801dd6b1eb4d107f7c2f643adf0a4e3ec9124/scripts/qemu-binfmt-conf.sh#L95) to get the kernel to forward execution via [binfmt](https://en.wikipedia.org/wiki/Binfmt_misc) of all s390x binaries in question to qemu-s390x.

**(TODO short showcase of how to enable binfmt with this fix. How to make a nixos system
"belive" it supports this arch. And show like a binaries headers of idk gnu hello and how we
run it on sth that `/proc/cpuinfo` denotes as lets say x86)**

## moving beyond binfmt 

After a bunch of crude hacks, overlays and disabled tests I managed to cross-compile the first nixos-s390x rootfs tarball.

**TODO: share it here + share the drvs needed to do so**

**TODO show neofetch and explain how one would build and export a nix system in tarball format**

While on first glance this looked promising. As expected when running an operation such as `nix-shell -p` or whatever deals with .drv's that aren't already known by hash to nix would fail.

**TODO show the actual error maybe**

Since I guess nobody before me bothered giving this a try <small>(maybe for a good reason)</small> nix wasn't
properly aware of how to actually build "literally anything" on s390x for s390x. This is due to the bootstrap package
missing and consequently not being able to build `stdenv`/`pkgs.stdenv`. 


{% alert(note=true) %}
Commands like `nixos-rebuild` or `nixos-install` won't work
without the means (`stdenv`) to compile stuff locally either. 
{% end %}

So either one has to accept being unable to build pretty much anything on s390x
itself and stick to cross compilation.

Or alternatively we **get stdenv working!**.

### "bootstrap tools" and overcoming infinite regression

When building a system from the ground up **(independently of nix)** it usually goes something like <q>you need a compiler to build a compiler to build a libc to build a compiler that builds a compiler ....</q>. But where would
that *"first compiler"* come from?

The problem presents itself a little bit similar to the chicken and egg
problem as in both cases at the core its [infinite regress](https://en.wikipedia.org/wiki/Infinite_regress)
that we need to overcome. Luckily in our case it can be solved but first we should establish some terminology:

### what exactly are "bootstrap tools"?

With nix we don't exactly start with just a compiler, we actually ship multiple executables. 

**TODO actually build the thing and just show an abstract raw from the terminal**

**TODO give https://trofi.github.io/posts/240-nixpkgs-bootstrap-intro.html some credit**

**TODO look at the most current drv as well at https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/linux/make-bootstrap-tools.nix**

These roughly look like:

**TODO do we want to talk about how its linked esp when trofi already did it?**

```
busybox (statically linked against musl)
gcc (this package and below are dynamically linked against glibc)
glibc binutils coreutils tar bash findutils diffutils sed grep awk
gzip bzip patch patchelf gmp mpfr mpc zlib isl libelf
```

The collection of these utilities is what one refers to in this context when talking about "bootstrap tools".

**TODO talk about how on nix its very important that this is pure and why shipping lets say busybox makes
a lot of sense instead of using the system coreutils or pretty much anything from the system**

### how to obtain "bootstrap tools"

While there are actually 2 ways to go on about obtaining/building these "bootstrap tools", I will focus on the
approach which cross compiles them like seen with risc-v for example.

{% alert(note=true) %}
For good reasons its very uncommon to build these "bootstrap tools" and
unless the architecture lacks support there is no need to do so.

**TODO: maybe show the error nix throws if the bootstrap tools don't exist yet**

**TODO fact check: I think unless you run the maintainer script nix will not build
them and just give up upon finding out that they aren't hosted anywhere as at some point
we declare them with "=" for the arch so It should trigger some sort of attribute not found
error or sth instead of attempting to build or complaining the drv lacks**
{% end %}


To get nix to build these bootstrap tools a few things need to be done before we can proceed:

1) describe the target in [lib/systems/examples.nix](https://github.com/NixOS/nixpkgs/blob/master/lib/systems/examples.nix) ... 
<small>this was actually the only thing already done and only requires like one line</small>
Taking a look at the entries here for lets say m68k , s390 as well as s390x 

```nix
{
  # ...
  m68k = {
    config = "m68k-unknown-linux-gnu";
  };

  s390 = {
    config = "s390-unknown-linux-gnu";
  };

  s390x = {
    config = "s390x-unknown-linux-gnu";
  };
  # ...
}
```

one sort of gets the point. Some "systems" are more involved though providing variables for libc/gcc(fpu+arch)/rustc/xcode/...
luckily we don't need to do that here.
<small>there are still some platform specific things to take care of as you will see later</small>

2) with [lib/systems/examples.nix](https://github.com/NixOS/nixpkgs/blob/master/lib/systems/examples.nix) from above now providing us with `pkgsCross.s390x` we can make the adequate change to `pkgs/stdenv/linux/make-bootstrap-tools-cross.nix` via [bootstrap-tools-cross: add s390x to make-bootstrap-tools-cross.nix #327715](https://github.com/NixOS/nixpkgs/pull/327715) which should get NixOS's CI "hydra" actually attempt to build this

3) Modifying `CROSS_TARGETS` in [maintainers/scripts/bootstrap-files/refresh-tarballs.bash](https://github.com/NixOS/nixpkgs/commit/313fc26d22d34e0dfb9c0922b3a687d03452199f) to include `"s390x-unknown-linux-gnu"`. As running this script will provide us with the urls/hashes and some metadata about these bootstrap files. This relies on 1) & 2) of course. The end result looks something like this:

```nix
# Autogenerated by maintainers/scripts/bootstrap-files/refresh-tarballs.bash as:
# $ ./refresh-tarballs.bash --targets=s390x-unknown-linux-gnu
#
# Metadata:
# - nixpkgs revision: 8ba481d65eb21a4f9e6b1e812de3f83079eb8016
# - hydra build: https://hydra.nixos.org/job/nixpkgs/cross-trunk/bootstrapTools.s390x-unknown-linux-gnu.build/latest
# - resolved hydra build: https://hydra.nixos.org/build/267960435
# - instantiated derivation: /nix/store/hqmllvbilxslp393ci4lkj66psh5iv6a-stdenv-bootstrap-tools-s390x-unknown-linux-gnu.drv
# - output directory: /nix/store/wnr3zf16ci8ajxnv0v6w3dn8lm93gp5z-stdenv-bootstrap-tools-s390x-unknown-linux-gnu
# - build time: Sun, 28 Jul 2024 14:47:36 +0000
{
  bootstrapTools = import <nix/fetchurl.nix> {
    url = "http://tarballs.nixos.org/stdenv/s390x-unknown-linux-gnu/8ba481d65eb21a4f9e6b1e812de3f83079eb8016/bootstrap-tools.tar.xz";
    hash = "sha256-fuKIRXznA8hU8uGpxldAUNvuJBZ/xiyJUByNbpBCaH8=";
  };
  busybox = import <nix/fetchurl.nix> {
    url = "http://tarballs.nixos.org/stdenv/s390x-unknown-linux-gnu/8ba481d65eb21a4f9e6b1e812de3f83079eb8016/busybox";
    hash = "sha256-R6nAiaIOgShKiu+qcOP9apVpnuJgTAGAsJxWSHsH4/A=";
    executable = true;
  };
}
```

and located at `pkgs/stdenv/linux/bootstrap-files/s390x-unknown-linux-gnu.nix`. We then need to source this in `pkgs/stdenv/linux/default.nix`. You can see the commits achiving this here: [stdenv: add bootstrap files for s390x](https://github.com/NixOS/nixpkgs/pull/332462/commits/398058603f13a57ca0ed891e81dcf6d39b9a9e05). 


{% alert(note=true) %}
the hydra builds get flushed within 2 weeks or something so don't let too much time pass when having the tarballs uploaded. This is done manually
still.

*As you can see below this mixed with another problem actually ended up in me having to push the bootstrapTools
urls/hash file twice ...*
{% end %}


[bintools-wrapper: add dynamicLinker for s390x](https://github.com/NixOS/nixpkgs/pull/332462/commits/bdb500ace1fdc02ab754c58302583e9c4f8ec17f) is also needed as otherwise while we got the bare bootstrap files working we can't properly link at further stages as the shared library loader would be wrong.

### unforseen consequences of forgetting a commit message 

**TODO mention that technially seen it wasn't required to put the pasta**

I wasn't sure if I should mention this as its quite unlikely that this will happen again. But I think its
interesting enough to still mention it **whomever reads this probably really won't
have to care about this again though**. So here we go:

I did make a tiny mistake with consequences a little bigger than anyone up until then expected. [Bootstrap-files updates amplifiy exploit of *any* package into exploit of *every* package](https://discourse.nixos.org/t/bootstrap-files-updates-amplifiy-exploit-of-any-package-into-exploit-of-every-package/50534) was the result of that mistake. I won't attempt to explain the issue here once more since its already touched upon in discourse.nixos.org but its still funny to note that essentially the only thing that lead to the discovery of this was:

[Bootstrap tools cross add s390x #332462](https://github.com/NixOS/nixpkgs/pull/332462)

not including the copypasta like seen in:

[pkgs/stdenv/linux: update s390x-unknown-linux-gnu bootstrap-files #334334](https://github.com/NixOS/nixpkgs/pull/334334).

>*(Despite the commits being functionally the same)*


**TODO maybe actually explain it showcasing the issue more in detail**


4) Won't really be carried out by you anymore unless well you have access to `tarballs.nixos.org`, it may still be interesting to see what would roughly take place though

```bash
nix-store --realize /nix/store/ijkl5anf7mx1p3whdkxv4qs5crf6ic35-stdenv-bootstrap-tools-s390x-unknown-linux-gnu
aws s3 cp --recursive --acl public-read /nix/store/ijkl5anf7mx1p3whdkxv4qs5crf6ic35-stdenv-bootstrap-tools-s390x-unknown-linux-gnu/on-server/ s3://nixpkgs-tarballs/stdenv/s390x-unknown-linux-gnu/0a7eaa55ccaa5103f44a9a4e3e0b06e5314a6401
aws s3 cp --recursive s3://nixpkgs-tarballs/stdenv/s390x-unknown-linux-gnu/0a7eaa55ccaa5103f44a9a4e3e0b06e5314a6401 ./
sha256sum bootstrap-tools.tar.xz busybox
sha256sum /nix/store/ijkl5anf7mx1p3whdkxv4qs5crf6ic35-stdenv-bootstrap-tools-s390x-unknown-linux-gnu/on-server/*
```

{% alert(note=true) %}
The previously mentioned security concerns resulted in 
commands listed above now automatically being included in that pasta
like seen at [pkgs/stdenv/linux: update s390x-unknown-linux-gnu bootstrap-files #334334](https://github.com/NixOS/nixpkgs/pull/334334)

**TODO I very very much feel like this but on second thought I may have put them there myself
but im weirdly confident about 
them already being there as I remember asking myself (is this a some github feature i don't know of?!)**
{% end %}

All of these changes should provide us with an stdenv sufficient to build some basic packages.
But of course a few more things require bootstrapping especially for languages that require
more involved forms of bootstrapping.

{% crt() %}
```
TODO find a way to not make the term waste space
when using ` ticks and language highlihting there
```
```sh
# TODO show how now:

nix build .#hello
./result/bin/hello

# appears to be working
```
{% end %}

### bootstrapping rust

Its 2024, rust is growing more and more popular and in fact
in no time you get stuck when building NixOS systems that aren't
extremely minimal. As *"something"* will end up depending on it
in some way. <small>(originally I wanted to add it much later on but
it kept showing up as a dependency ... luckily its rather trivial to add)</small>

**TODO: factcheck I think this even happens with the default profiles (rust being a dep)**

 [rust: S390x add native support (bootstrap files) #337908](https://github.com/NixOS/nixpkgs/pull/337908) and  [openblas: Enable s390x-linux #337907](https://github.com/NixOS/nixpkgs/pull/337907) take care of that.

 <small>Assuming we forget about haskell since they refuse to offer bootstrap packages for s390x or riscv or some other cpus and cross compiling these is a pain and there are issues specifically on s390x (riscv sorta works).
 **TODO maybe link the issues**</small>


### gcc.arch (march) matters ...

While for now most work focussed on bootstrapping things
and it should be *"enough"* to build most pkgs and even
a basic nixos system natively. This is with the assumption
that `gcc.march` is set adequately. 

**TODO: show the actual errors**

> Honestly as I don't feel like touching llvm for now and it
may not be trivial to fix this there is a way to prevent
running in various `gcc.arch` related issues during various builds:

{% alert(caution=true) %}
**NOT specifying `gcc.arch = "z10";` OR NEWER
WILL LIKELY CAUSE BUILD FAILURES**<small>(working on it though)</small>

It should be possible to avoid these issues by
essentially just setting `gcc.arch=z10;` or `gcc.arch=TODO_FURTHER_ARCHES_NAMES` like seen below.

Until the decision is made on whether to set this within nixpkgs to `"z10"` or newer, you can
use something like this in your configuration.nix / flake.nix

```nix
{
  nixpkgs.hostPlatform = {
    system = "s390x-linux";
    # linux-kernel = { ... };
    # ... other settings
    gcc.arch = "z10";
  };
}
```

{% end %}

<small>Personally I think there is little point to
supporting anything older than the Z10 (2008) 
because it seems to cause significantly more issues
and there is another problem:
~~even IBM's bootloader appears to assume
that the march is no older than Z10~~
**(TODO start of 2025 IBM fixed this
after I pointed it out to them)!!!!**
</small>

### obscure errors during `testPhase`?


<small>**TODO talk about failing tests
and stuff while they should be mostly fixed by
now mention that at times esp to move forward
its ok to temporarily ignore some tests maybe
for the sake of getting things to build. Crude
but I wanted a PoC ASAP**
</small>

---
<small>getting bored? Don't worry
now that we have established the required
basis to build a proper nixos sytem
...
**things may get more interesting now**
</small>

---

# making our system bootable

With the fixes/commits/settings previously mentioned applied,
the only NixOS systems <small>(as build in via: `nixpkgs.nixosSystem {}`)</small>
are essentially everything that does not require:

- the bootloader (zipl)
- the kernel image
- the initrd

that effectively means:

- using a tarball (without kernel/initrd/bootloader) as the output format
- using container images <small>(essentially a system rootfs tarball + metadata)</small>

a little bit further down we take care of the absence of these 3 things. Though
for those interested this is how to construct such container/tarballs:

**(TODO maybe show how build a tarball / container)**

## enable NixOS to build kernels / initrds

Like implied previously boot methods such as: 
- [ISO 966](https://en.wikipedia.org/wiki/ISO_9660)<small>(also known as simply ".iso" files)</small>
- kexec
- zipl

all require some sort of kernel image + initrd. This part describes how enable NixOS to build these:

### building the kernel

To get NixOS to attempt to build a kernel we first
need to give it some details it will use when attempting to build the kernel.

In this case telling it that the `baseConfig` shall be taken from the platform (s390x)
specific <small>(kernel)</small> defconfig. And that the target to be expected is `"bzImage"` is enough.


```nix
{
  nixpkgs.hostPlatform = {
    system = "s390x-linux";
    linux-kernel = {
      target = "bzImage";
      name = "s390x-defconfig";
      autoModules = true;
      baseConfig = "defconfig";
    };
  };
}

```
{% alert(tip=true) %}
While if you actually end up building this
specifically for some (IBM Z) mainframe
the linux kernel does in fact have varoius arch/target
specific specifc optimisation flags. Feel free to use
them or even better see what they do first.

**TODO link the options I'm talking about here**
{% end %}

> <small> This will probably make it into nixpkgs platform
specifications (there are still things that need to be discussed).
In that case you wouldn't need to do this anymore but until then
or just as a general *"method"* thats how it can be done </small>

**TODO: give some insight in how nix actually builds the kernel
and how these variables make it there**

### building the initrd

**TODO reword this part** 

By default the `linuxArch` is set to `"s390"`
not `"s390x"` <small>(just like it would select `x86` instead of `x86_64`)</small>. As that compiles just fine one may expect it to
work just fine as well but sadly thats actually not the case as for `"s390"`. 

**TODO link where this happens**

For example the `ifconfig` utility found within the initrd
which is invoked when passing `"ip="` type parameters trough the kernel commandline
will actually thorw an obscure **"parsing error"**


{% crt() %}
```
TODO <paste the actual error here>
```
{% end %}

For some reason this doesen't happen on the 64bit 390x counterpart.

While klibc does actually claim to support s390 I couldn't get this properly runnig with
ifconfig.


### can we just use 64bit?

sort of ... and honestly if using 64bit works without these
obscure issues. I belive that <small>(at least for now)</small> it should be fine.

{% alert(note=true) %}
The reasoning to use an `linuxArch` with a smaller bitsize **TODO or how do you call this**
exclusively within the initrd is for size binary reasons. Shorter Pointers and opcodes
naturally produce smaller executables than if the bitsize **TODO how to call this** was for example 2x as big
{% end %}

to be honest I think that the size argument is much less relevant on mainframes when
booting via zipl. As the files are actually commonly found on the systems "/" partition
which shouldn't lack storage like mainframes in general.


{% alert(warning=true) %}
**TODO find it again: there was this one case (was it cdrom?) where either both combined 
or maybe individuallly kernel and initrd had to be below a certain size**

In such cases maybe one actually benefits from a smaller `linuxArch`. I think this shouldn't
matter though as long as one doesn't build initrds with a lot of *"extra utilities"*.

<small>In such cases though thats usually due to more involved crypto key
retrival operations. (ipsec/wg/tor/...) and in such cases I think using 32bit
may actually be a security concern.</small>
{% end %}


This may be a little more relevant if it was common to use some form
of a dedicated `"/boot/"` partition instead <small>(like see with EFI vfat32 based
boot partitions)</small>. But I guess as long as the zipl bootloader is used its fine to just boot from `"/"`.

**TODO include notice of**: sth like: ( This of course assumes that your filesystem allows these old style bootloaders, ext4 does) < name how these sort of bootloaders that just sorta
remember the location of a file on the filesystem are called> blockdevice and load that ... as afaik zipl only works with this kind of filesystem >

**TODO: talk more about how the bootloader works in detail maybe**

---

so ... are we finally good to go?

---


## first boots (AND debugging them with limited tools)

I guess before things get a little ugly. I should point out that
of course a few more settings need to be done and of course
you need an actual nixos system configuration to build. Instead
of going trough every snippet especially as a lot of them
may change in the future I will just link [my confgigs](https://github.com/bolives-hax/nixos-s390x-images/blob/master/flake.nix).
As for now I'm more or less using [this commit](https://github.com/bolives-hax/nixos-s390x-images/commit/cade49a7dfbd4bb48145f48456a38faa84550c9b)
which despite being a little crude does at least produce working

- lxc compatible images
- kexec bundles (live systems)
- rootfs tarballs
- cdrom images <small>(will touch on that later on)</small>

Getting whatever I produced to actually boot up succesfully isn't quite as straightforward
as I hoped it would be. Thats why the next section first points out the limitations I faced
and how I worked around them.

### The restrictions

Well honestly the biggest issue is the **complete absence** of a serial interface on the Z15 mainframe provided to me by IBM

{% alert(note=true) %}
I did contact IBM regarding the absence of a serial out of bounds console
and while they sadly couldn't provide me with this please
keep in mind that this is not an issue people using the comercial platforms
would face.
{% end %}

So since I brought it up before and even included a picture. You may wonder:

<q>hey what about the Z10 why don't you just use that?!</q>


<aside> pic related: {{ image(url="https://files.catbox.moe/t3611w.jpg", alt="power_plug_used_pic", no_hover=true) }}</aside>

Well as you can probably tell by the picture, just using the closest ordinary poweroutlet
won't really cut it. In fact there is 2 problems 

- (**TODO say a little about the connector, where its found, how it differs from ordinary
one and well trough this point out why we essentially need this) (and say the outlet for "this" is far away and the cable had to be made bla bla)**

- {% alert(important=true) %}
 **TODO explain the FI trip mechanism as well) Additionally turns out the (TODO translate FI schutzschalter) would actually trip with the default (TODO FI term). (TODO list what strengths were used I believe it was 30mA and eventually 300mA TODO confirm this).**

>((As an interesting sidenote up until the Z **TODO which Z-series** mainframe, having a relatively high leakage current apparently was the norm as it could be attributed to the way IBM
designed the **?power distribution circuts TODO or how to call this?**. So
actually having a **TODO english term for FI** trip is the expected behavior eventhough one may be
under the assumption that this is not the intended behavior.))

{% end %}

### other reasons:

- While being able to play around with a IBM Z15 mainframe is definitively something. Nobody
except me would really benefit from me getting to run NixOS on it. But in all honesty this
would be a waste of resources. IBM is paying the power either way and the idea after all
is to use this for developping/building open source community projects.

- As IBM already agreed to provide me with additional resources on the Z15 to make it
part of the offcial NixOS CI. I decided to talk with some folks from the NixOS infra team who
gave their OK and the current plan is to use this server to offer
cached packages/drv builds for nixos on s390x stemming from an officially trusted source

- The Z15 is also obviously much newer and performs better in quite a few scenarios

so all in all it makes sense to use what they provided me with and the most desirable
outcome would be that its being used for hydra / cache.nixos.org 


### what are the implications of using IBM's Z15 instead of the Z10?

Concretely this means: I am **completely "blind"** until ... well ... "something" boots up and responds to me

Of course I knew that this would cause me a lot of pain ~~but then I seem to get lucky at times~~.

### What about using emulators?

Luckily emulators while slow
(especially [Hercules](https://en.wikipedia.org/wiki/Hercules_(emulator)))
are still a viable choice. 
Qemu in fact is fast enough for me to not really be bothered especially
when running *"minimal linux kernels/userland applications"*. As unlike the Z15 hosted by IBM
qemu does provide me with a serial console. The idea of using that until I confirmed that my initrd
was somewhat behaving like expected made sense to me at that time

<mark>I must already give you a heads up here, things weren't as simple
<br>...<br>
(I could have expected that)</mark>

Just like with kexec to boot this in qemu we need a kernel+initrd image
to pass over the commandline.

<small>(unless were ok with using iso images. But as of
**numours issues** usually of the _"I wish someone would have told me"_-kind 
I didn't manage to produce these yet at that time</small>

#### building the NixOS-system components

**TODO either modify the snippets below to use qemu or mention
that I was just copying the paths from the kexec script as its
functionally almost the same**

Well while you can of course look at the config it does go somewhat like:

1) import the `<nixos/modules/installer/netboot/netboot-minimal.nix>` module
> while we aren't going to netboot we still don't want to split initrd
and whatever holds the root system. <small>You will see later why simplicity is key</small>

2) using some form of Mic92s [kexec script](https://gist.github.com/Mic92/4fdf9a55131a7452f97003f445294f97)
<small>(while I don't use it the concept is pretty much the same)</small>.
The attribute set spit out by `nixpkgs.lib.nixosSystem {}`
has the `config` attribute from which specifically `config.system.build` is of interest to us. Thus 
```nix
{
    x = nixpkgs.lib.nixosSystem {
        # ... the config
    };
}
```
would make `x` expose `x.config.system.build` and consequently:

- `x.config.system.build.toplevel`
- `x.config.system.build.netbootRamdisk` (comes from the `netboot-minimal.nix` module we loaded before)
- `x.config.system.build.kernel`

As these are all derivations we can also build them individually using
nix build or use the `${}` operator on them. As all derivations
produce an `.outPath` <small>(/nix/store/`<hash>`-name)</small>

`.toplevel` Is the store path to something that qualifies as an
nixos system. Of particular interest here would be `${system.build.toplevel}/init` as we
need to pass that via the kernel commandline <small>(`init=`)</small>. 

`.netbootRamdisk` is essentially a _"fat initrd"_. As initrds usually just
contain a very minimal linux environment to mount the actual root drive.
We need to specifically build one that actually houses our entire system

`.kernel` I believe needs no explaination. Though keep in mind that the
location may differ. Here it should be bzImage **TODO confirm this**
**TODO maybe explain how nix chooses the kernel image format and
how to retrive it**

while not a derivation `.config.boot.kernelParams` is also integral
as it contains effectively our kernel commandline that we either
pass to kexec via `--commandline` or qemu via `--append`. Retriving
this can simply be done trough calling `toString` on it like
`${x.config.boot.kernelParams}` or using `nix eval` **(TODO show an example for eval)**


**TODO check if this simplified snippet actually works like mine**

If we wanted to output this as a kexec script it would look something like this:
```nix
{
    kexecScript = pkgs.writeScriptBin "kexec-boot" ''
      ./kexec --load ${x.config.system.build.kernel}/bzImage \
      --initrd=${x.config.system.build.netbootRamdisk}/initrd \
      --command-line "init=${x.config.system.build.toplevel}/init ${toString x.config.boot.kernelParams}"
    '';
}
```
**TODO test the qemu one and put it on git as well and maybe make it
a little smarter than hardcoding mem like via nix run and accepting
dunno additionall params or sth like -m or -net instead of hardcoding them**

```nix
{
    qemuScript = pkgs.writeScriptBin "qemu-boot" ''
    ${pkgs.qemu}/bin/qemu-system-s390x -M s390-ccw-virtio \
        -m 2048 -smp 4 -nographic  \
        -net nic -net user \
        -kernel ${x.config.system.build.kernel}/bzImage \
        -initrd ${x.config.system.build.netbootRamdisk}/initrd \
        -append "init=${x.config.system.build.toplevel}/init ${toString x.config.boot.kernelParams}"
}
```

**TODO mention how to use nix repl to elegantly retrive
these**

**TODO talk about the limited set of drivers, that dasd's can't be emulated here (TODO are you 1000% sure)
and youd need hercules (maybe also show how to do that)** 

## booting NixOS (qemu)

if we either extract the variables from above or use the kexec script we build we will end up
with

```sh
qemu-system-s390x -M s390-ccw-virtio \
    -m 2048 -smp 4 -nographic  \
    -net nic -net user \
    -kernel /TODO/NIX/STORE/aaaaaaaaaaaaaaaaaa/bzImage \
    -initrd /TODO/NIX/STORE/aaaaaaaaaaaaaaaaaa/initrd \
    -append "init=${x.config.system.build.toplevel}/init ${toString x.config.boot.kernelParams}"
```

{% alert(tip=true) %}

For a variety of reasons when doing these sort of things its <mark>very useful</mark> to
be able to drop a shell in the early initrd stages upon failure. Like when
adding `boot.shell_on_fail` to the kernel commandline. But also deliberately dropping it.
It is quite likely that you will
need to drop it specifically during various stages of the initrd. There are a few
kernel commandline parameters that can be used (besides just patching the init template scripts of course):

- `boot.debug1` **TODO im not sure anymore if the serial console
provided by qemu is already usable/configured in this stage of the init**

- `boot.debug1devices`

- `boot.debug1mounts`

- `boot.trace` (I almost kept this on until the very end. <small>May slow down the boot process slightly though</small>)

{% end %}


{% alert(important=true) %}
**serial console ignoring keystrokes?!**

Keep in mind that __(if present)__ on s390/s390x the native
console type is SCLP. Linux thus assigns the console a name
such as: `/dev/ttysclp0` __(in my case as the first serial console)__

As of the way the NixOS's init scripts are designed you can only configure one
terminal interface to function in a bidirectional fashion. This is the first terminal
specified over the kernel commandline. If left unspecified __(in qemu but maybe also
in other places)__ the console chosen may not actually be exposed to you
in a way where you can actual issue any inputs. Which makes dropping a shell
impossible.

When systemd takes over later on into the bootprocess and launches
actual services to set up the various consoles for the second time it shouldn't matter. But
if for any reason you require a functional console earlier on. Be it to 
provide your disk unlocking mechanism or to provide you with
a functional debug+rescue shell environment. You have to set this correctly
or you simply won't be able to interface with your host
{% end %}

**TODO mention that -cdrom isn't actually scsi or whatever but virtio
and the implications of that in terms of cdrom boot not working
https://www.ibm.com/docs/en/linux-on-systems?topic=virtio-ccw-device-specifications
essentially SCSI Host Bus Adapter (virtio-scsi) and Block (virtio-block) aint the same**

**TODO terminal abstract of this actually sort of working**

### booting Alpine Linux ?!

>**wasn't this an article about NixOS why would one talk about alpine linux now?!**

While my build would actually come up __"when directly booting into the kernel/initrd"__ . There
were still some things that would not work. (most importantly networking).

As alpine was tested to at least run in qemu
I settled with attempting to actually boot
something thats known to work as well. Having a working setup to use as a reference
or just to query certain hardware information proved quite useful. Also quite a few tools are pre-packaged
so I'd not have to bother as much fixing NixOS package builds(drv's) before I got a host natively running NixOS

Alpine linux ended up being my distro of choice as it provided
the most straightforward way to boot into a linux system
by just offering kernel/initrd/etc images at:

[https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/s390x/netboot/](https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/s390x/netboot/)

Having direct access to the files making up the kernel + initrd does not only mean
I can run this in qemu. But also that I could make use of kexec later on like on the Z15.

Which is quite neat as opposed to
having to bake an .iso image or such things which tends to involve much more things
that can go wrong. <small>(Sometimes netboot is an option as well but I didn't look into that)</small>

Thus after downloading the files in question from there one could attempt something like:

```sh
qemu-system-s390x -M s390-ccw-virtio \
        -m 2048 -smp 4 -nographic  \
        -net nic -net user \
        -kernel vmlinuz-lts  \
        -initrd initramfs-lts \
        -append "ip=dhcp alpine_repo=https://dl-cdn.alpinelinux.org/alpine/v3.19/main modloop=https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/s390x/netboot/modloop-lts"
```

{% alert(important=true) %}
(make sure that the files provided via the "-kernel" and "-initrd" flags match the version
of whats specified  via alpine_repo AND modloop! 
{% end %}

{% alert(note=true) %}
this relies on a properly working WAN internet connection (including dns ofc).
It also takes quite a while when using emulation (instead of kvm accel) and most
importantly if emulation is VEEERY slow or if your network is unstable this may fail
and drop you off into an emergency shell.

Definitively suboptimal but as long as you
are aware of these things it shouldn't be a huge issue. If you get errors suggesting some remote
resources can't be found (**TODO example**) you may have a version mismatch.
<mark> Please make sure all the files come from the same release.
You can also use the emergency shell to debug the network configuration if you suspect something
is off. </mark>
{% end %}

After running the command above pretty much instantly im presented with
{% crt() %}

```
ASLR disabled: CPU has no PRNG
KASLR disabled: CPU has no PRNG
[    0.539393] Linux version 6.6.32-0-lts (buildozer@build-edge-s390x) (gcc (Alpine 13.2.1_git20240309) 13.2.1 20240309, GNU ld (GNU Binutils) 2.42) #1-Alpine SMP Fri, 24 May 2024 08:38:05 +0000
[    0.541762] setup: Linux is running under KVM in 64-bit mode
```
{% end %}
indicating that its about to boot, further down I saw:

{% crt() %}
```
 * Mounting boot media: [   13.341232] Mounting boot media: ok.
ok.
[   13.604847] Obtaining IP via DHCP (eth0)...
 * Obtaining IP via DHCP (eth0): udhcpc: started, v1.36.1
[   13.900690] NET: Registered PF_PACKET protocol family
udhcpc: broadcasting discover
udhcpc: broadcasting select for 10.0.2.15, server 10.0.2.2
udhcpc: lease of 10.0.2.15 obtained from 10.0.2.2, lease time 86400
[   14.903964] Obtaining IP via DHCP (eth0): ok.
ok.
[   16.258689] Installing packages to root filesystem...
 * Installing packages to root filesystem: fetch https://dl-cdn.alpinelinux.org/alpine/v3.19/main/s390x/APKINDEX.tar.gz
(1/26) Installing alpine-baselayout-data (3.4.3-r2)
```
{% end %}

and then finally

{% crt() %}
```
 OpenRC 0.52.1 is starting up Linux 6.6.32-0-lts (s390x)

 * /proc is already mounted
 * Mounting /run ... [ ok ]
 * /run/openrc: creating directory
 * /run/lock: creating directory
 * /run/lock: correcting owner
 * Caching service dependencies ... [ ok ]
 * Remounting devtmpfs on /dev ... [ ok ]
 * Mounting /dev/mqueue ... [ ok ]
Connecting to dl-cdn.alpinelinux.org (151.101.130.132:443)
saving to '/lib/modloop-lts'
modloop-lts          100% |********************************| 17.5M  0:00:00 ETA
'/lib/modloop-lts' saved
 * Mounting modloop /lib/modloop-lts ... * Verifying modloop
 * Failed to verify signature of !
 [ ok ]
 * Mounting security filesystem ... [ ok ]
 * Mounting debug filesystem ... [ ok ]
 * Starting busybox mdev ... [ ok ]
 * Scanning hardware for mdev ... [ ok ]
 * Loading hardware drivers ... [ ok ]
 * Loading modules ...modprobe: can't change directory to '6.6.32-0-lts': No such file or directory
modprobe: can't change directory to '6.6.32-0-lts': No such file or directory
 [ ok ]
 * Not setting clock for s390 system
 * Checking local filesystems  ... [ ok ]
 * Remounting filesystems ... [ ok ]
 * Mounting local filesystems ... [ ok ]
 * Configuring kernel parameters ... [ ok ]
 * Migrating /var/lock to /run/lock ... [ ok ]
 * Creating user login records ... [ ok ]
 * Cleaning /tmp directory ... [ ok ]
 * Setting hostname ... [ ok ]
 * Starting busybox syslog ... [ ok ]
 * Starting firstboot ... [ ok ]

Welcome to Alpine Linux 3.19
Kernel 6.6.32-0-lts on an s390x (/dev/ttysclp0)

localhost login:
```
{% end %}

**TODO there seems to be a can't change directory issue here ... fix it**

{% alert(tip=true) %}
logging in as root requires no password and drops a shell
{% end %}

While emulated now we at least have some solid ground under our feet to
test our initrd or pretty much all software on. I extensively made use of this
to test out things before I could get them to run on real hardware from executables
to kexec-ing into other things to just checking network connectivity. <small>(of course packages
can be installed via `apk add` as for example kexec is not present by default)</small>

{% alert(note=true) %}
Please keep in mind that the virtio hardware thats being emulated
is **quite different** from what you may find when trying to pull of any of these things
on an actual s390x host. Interface names may be different, the drivers used are most
definitively different and as you will see later setting up disk/network appears to be
much more involved than loading the kernel module ... 
{% end %}

**TODO explain how I tested nix before testing NixOS by essentially putting /nix into the alpine and starting the daemon manually ...**


## booting NixOS (IBM Z15)

By the point everything seemed fine in qemu. I decided to run it natively
on the Z15 I mentioned earlier. The initial idea was quite simple:

**TODO compare this with the actual command this is simplified**

**TODO make sure to mention that no root disk is needed
in this case as it uses a modified version of Mic92s kexec thingy**

```sh
kexec ./bl0v3s-s390x-nixos-kernel \
    --initrd=./bl0v3s-s390x-nixos-initrd \
    -append="ip=dhcp" -l

kexec -e # to execute the loaded os
```
{% alert(note=true) %}
running the command above or any kexec call won't give you
any feedback unless it fails before jumping to the new
kernel. This means that until whatever you booted manages
to notify you in some way <small>like trough the serial console
which isn't present in my case ...</small> you have no
way of knowing if its still loading. Crashed or came up
but failed to notify you <small>(for example if you rely on
ssh/icmp like I do)</small>. Turning you essentially blind
{% end %}

{% alert(note=true) %}
Well, while this is specific to the network environment IBM uses on the
machine given to me. There already is an issue: `ip=dhcp` won't cut it
because they actually don't offer dhcp. <mark>which is perfect fine as
under normal conditions you'd never have or rather want to interface
with the network in that way but just sort of let them administer the
system for you</mark>
{% end %}

**TODO show how I modified stage 1 to drop me an ssh shell (if it would have worked)**

Which meant changing the append parameter found in the kexec call above to something like:

`--append="ip=148.100.85.113::148.100.84.1:255.255.254.0:nixos:eth0::9.9.9.9:8.8.8.8"`

with:
- `148.100.85.113` being the ip statically assigned to eth0
- `148.100.84.1` being the gateway
- `255.255.254.0` being the subnetmask (a `/23` essentially)
- `nixos` being the hostname
- `eth0` being the target interface to assign these values to
- >`9.9.9.9` and `8.8.8.8` are dns servers run by cloud9 and google as fallback.
<small> {% alert(note=true) %}
(not too relevant for our nix host but running alpine like described above would
actually require this when resolving domains as it sort of is a "minimal netboot" image)</small>
{% end %}

For reference here is the network configuration (excluding v6) directly
taken from the Z15 when it was running something that offered me a shell:

```sh
# show the ip address configuration
ip a show eth0

# show the routes (focus on "default")
ip r
```

{% crt() %}
```
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 02:02:12:f4:34:1a brd ff:ff:ff:ff:ff:ff
    inet 148.100.85.113/23 scope global eth0
       valid_lft forever preferred_lft forever
```
{% end %}

and for the route

{% crt() %}
```
default via 148.100.84.1 dev eth0 proto static
```
{% end %}

seems correct. Especially with the initrd userland using 64bit ifconfig
should be able to make sense out of the kernel commandline, right? Well actually **it does**
only issue is that <mark>**it really aint that simple**</mark>

**TODO add how I confirmed that networking this stuff worked in qemu and even initrd sshd stage1**

**TODO mention how and why I turned off predictable interface foo**

{% alert(important=true) %}
**TODO explain [Persistent device configuration](https://www.ibm.com/docs/en/linux-on-systems?topic=resources-persistent-configuration).
And why this is a thing. And most importantly why this is not the sort of approach one
would want to use in NixOS (declarative distros). As it heavily relies on udev
and rebuilding the initrd to contain the "persistent" effectively udev rule changes**
{% end %}

So at this point in time my assumption was that it probably is lacking drivers.

A quick way to check without using any
specialized commands that may not be present is going
via sysfs. So in this case with our interface being named `eth0`
running:

```sh
ls -l /sys/class/net/eth0/device/driver/
```

reveals:

{% crt() %}
```
...
lrwxrwxrwx 1 root root    0 Feb  3 01:18 0.0.1000 -> ../../../../devices/qeth/0.0.1000
--w------- 1 root root 4096 Feb  3 01:20 bind
--w------- 1 root root 4096 Nov 10 12:04 group
lrwxrwxrwx 1 root root    0 Feb  3 01:20 module -> ../../../../module/qeth
--w------- 1 root root 4096 Feb  3 01:20 uevent
--w------- 1 root root 4096 Feb  3 01:20 unbind
...
```
{% end %}

so `module -> ../../../../module/qeth` is suggesting the `qeth` driver is responsible
for this interface. Now looking at `lsmod | grep qe` shows:

{% crt() %}
```
...
qeth_l3                65536  0
qeth_l2                57344  1
bridge                348160  1 qeth_l2
qeth                  163840  2 qeth_l3,qeth_l2
qdio                   61440  2 qeth,qeth_l3
ccwgroup               20480  1 qeth
...
```
{% end %}

**TODO provide an more elegant way how one would have come
to the conclusion thaht qeth_l2 is needed instead of seeing
it and just loading it**

**TODO qeth_l3 isn't needed right. I forgot sort of need to test via kexec**

The only thing that caught my attention was `qeth_l2` and `qeth_l3` which both depend on `qeth`.
But there also is `ccwgroup` which I have never heard of but **made the fatal flaw of believing
I won't need this ...**

Well I tried and tried but it just wouldn't work. At one point loading pretty
much any module there is.
<mark>
Always keep the previously described
restrictions of actually not having a serial 
console in mind
</mark> 

### running alpine (Z15)

Maybe alpine linux would load the proper modules or do things
I don't know about yet. So why not give alpine a shot again then:

**TODO test V**
```sh
# TODO test this actually please
kexec vmlinuz-lts  \
        -initrd=initramfs-lts \
        --cmdline="ip=148.100.85.113::148.100.84.1:255.255.254.0:nixos:eth0::9.9.9.9:8.8.8.8 alpine_repo=https://dl-cdn.alpinelinux.org/alpine/v3.19/main modloop=https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/s390x/netboot/modloop-lts"
```

#### what if I kexec'd whats already running?!

It wasn't long until I suspected that kexec simply
doesn't work. While s390x [has kexec support](https://github.com/torvalds/linux/blob/2014c95afecee3e76ca4a56956a936e23283f05b/arch/s390/Kconfig#L283) maybe the hardware
or maybe rather hardware configuration somehow prevents it. You never know
its a mainframe after all. Only one way to find out:

**TODO show abstracts of the original zipl config from IBMs default OS choices**

So assuming these details are correct lets just call `kexec` in the same way
the pre-installed zipl installation called kernel+initrd+cmdline:

```sh
kexec ./TODO show the command
```

as I was anxiously awaiting an icmp reply after running the previous command
made it stop replying to pings for obvious reasons <br>...<br>

<mark>**Its up!** and responding to icmp!!</mark>
<small>(followed by
a weirdly long period of silence that got me slightly worried but
eventually it was allowing me to log in via ssh)
</small>

Ok so its safe to say that my fear of **kexec NOT working** was **proven wrong**,
great!

{% alert(note=true) %}
In such a situation it may be smart to append a tiny exta line to your
cmdline to make sure your machine actually booted trough kexec instead of
somehow having just rebooted which in this case would have had the same result
but appending a tiny piece to the cmdline allows us to check `/proc/cmdline`
and compare it to the default invoked by a reboot
{% end %}

So what could be making not just my initrd but also alpine fail? In alpines
case I can't even argue that a driver may be missing as I'd be rather sure
that they thought of that. Its most definitely should be possible to run this
places other than just qemu I figured.

### alpines `s390x_net=` option

I ended up asking IBM but before they got a chance to reply, a friend pointed
out to me that there is a kernel cmdline option called `s390x_net=`. I never heard of
this option though. So I started digging. Since I couldn't find it listed in any
official kernel resources [documenting the kernel parameters](https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html)
the only option left would be that the init takes care of it.

As previously pointed out `/sys/class/net/eth0/device` in my case linked to `0.0.1000`
like we can see here:

`lrwxrwxrwx 1 root root    0 Feb  3 01:19 device -> ../../../0.0.1000`

and running `ls -la /sys/devices/qeth` reveals:

{% crt() %}
```
drwxr-xr-x  3 root root    0 Feb  3 17:05 .
drwxr-xr-x 14 root root    0 Nov 10 12:04 ..
drwxr-xr-x  5 root root    0 Jan 14 13:02 0.0.1000
lrwxrwxrwx  1 root root    0 Feb  3 17:05 module -> ../../module/qeth
-rw-r--r--  1 root root 4096 Feb  3 17:05 uevent
```
{% end %}

it made sense to assume this should be set to `0.0.1000`. So I gave it a shot setting
`s390x_net=0.0.1000` but nope. Googling the option dind't really seem to help and
I don't know of many alpine linux resources for s390x.

By now I realized that its probably not the best idea to continue digging here if I don't even
know if NixOS or alpine actually boot. As in that case even if I set the correct option here
but some other part of the boot process would fail. I'd not even be able to tell <small>(as
pointed out earlier) serial isn't an option in this specific case</small>

**TODO point out that for qeth its always 3 id's VV**
- read
- write
- data bus ID of your virtual network card

### unconventional logging methods

I'd need some way of knowing the state the system is in post kexec. With network/serial
based methods being out of the question, one of the things that remained was the disk. 

#### dasd - (Direct Access Storage Devices) 

**TODO reformat and remove the >**
> While configuring storage in my case (dasd)(**TODO explain it a lil and link**)
was still a little simpler than just loading the right modules and having a `/dev` node
for the blockdevice show up. It had one advantage over `s390x_net=` which is that
the `dasd` kernel commandline parameter is much more common to encounter.

For example the [gentoo S390 install guide](https://wiki.gentoo.org/wiki/S390/Install)
provides a sample zipl configuration `/etc/zipl.conf`:

```
[defaultboot]
defaultmenu = menu

[Gentoo]
    image = /boot/image
    target = /boot/zipl
    parameters = "dasd=0150 root=/dev/dasda1 rootfstype=ext4 TERM=dumb net.ifnames=0"

:menu
    default = 1
    prompt = 1
    target = /boot/zipl
    timeout = 10
    1 = Gentoo
```

with `dasd=0150` being what I'm after. Of course this wouldn't be `0150` but looking in
`/sys/class/block/dasda/device -> ../../../0.0.0100` suggestes giving `0.0.0100` a shot.


{% alert(note=true) %}
In the hardware configurations encountered in this article
both `0.0.0100` and `0.0.1000` are brought up.
Make sure to not confuse them by accident

<small>(yes this happened to me)</small>

{% end %}

So lets get our kexec's `--append`'s (kernel commandline) statement to include `dasd=0.0.0100`


```sh
kexec -l ./bl0v3s-s390x-nixos-kernel \
    --initrd=./bl0v3s-s390x-nixos-initrd \
    -append="dasd=0.0.0100"
```

> I left out the network configuration because it didn't work for now either way and
I wanted to reduce the amount of things that could somehow affect the boot process
(<small>not just slowing it down</small>) . But it probably would have been fine to leave
it there its simply good practice.


{% alert(tip=true) %}

Unlike `s390x_net=` the `dasd=` kernel commandline option is actually handled by the kernel.
Thus you can make the kernel online it without the initrd/initramfs being involved yet

**TODO factcheck this once more (memory sucks)**

{% end %}


in the linux kernel source tree `/drivers/s390/block/dasd.c` **TODO permalink** we can
see a notice regarding the `dasd=` kernel commandline parameter:

```C
/*
 * Initial attempt at a probe function. this can be simplified once
 * the other detection code is gone.
 */
int dasd_generic_probe(struct ccw_device *cdev)
{
	cdev->handler = &dasd_int_handler;

	/*
	 * Automatically online either all dasd devices (dasd_autodetect)
	 * or all devices specified with dasd= parameters during
	 * initial probe.
	 */
	if ((dasd_get_feature(cdev, DASD_FEATURE_INITIAL_ONLINE) > 0 ) ||
	    (dasd_autodetect && dasd_busid_known(dev_name(&cdev->dev)) != 0))
		async_schedule(dasd_generic_auto_online, cdev);
	return 0;
}
```


{% alert(important=true) %}
**TODO explain autodetect and ccw and whatever to point out that you
have to use dasd= (or udev effectively trough chzdev from s390-tools
or what it was again)**

(**TODO figure out how the autodetect works and maybe explain it**)
**online all devices"**

/sys/bus/ccw/drivers/ [this page](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/installation_guide/chap-post-installation-configuration-s390#sect-post-installation-adding-dasds-s390) 

**TODO point out how I initially onlined it using echo 1> .... /online in my initrd init script**

{% end %}

**TODO show how I modified my initrd to mount the dasd and first write hello world and later on some state.
Mention why I first checked if the dasd works before instantly dumping network crap**

Well remember alpines `s390x_net=` that I didn't want to play around with until I
found some (admittedly crude!) way of getting some form of log output. Now that retriving the logs
works I guess a sane question would be:

<q>"why don't you just look at the code?"<small>(its probably going to take less time than finding a resource explaining this)</small></q>

**TODO use permalinks**

so looking into how alpine creates their intiramfs's I came to the conclusion that
[alpines mkinitfs repo](https://gitlab.alpinelinux.org/alpine/mkinitfs) would be the place to look.

The [initramfs-init.in](https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in) file contains what I was
looking for. At [line 471](https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in#L471) the `myopts=`
variable is being introduced. Containing various options some commonly known like
`ip` <small>(remember the `ip=` statement)</small>.  Other than that for example `ssh_key` one can use to make for example the netboot images
we used earlier retrive that from a remote resource so we don't have to bake our own kernels/initrd's. <mark>Line 530 to 536</mark>
would then make sense of `myopts` by effectively doing the following:

**TODO explain that its breaking these down and assigning this to the KOPT shell variables**

```bash
for i in $myopts; do
	case "$opt" in
	$i=*)	eval "KOPT_${i}"='${opt#*=}';;
	$i)	eval "KOPT_${i}=yes";;
	no$i)	eval "KOPT_${i}=no";;
	esac
done
```

Further down starting [at line 607](https://gitlab.alpinelinux.org/alpine/mkinitfs/-/blob/master/initramfs-init.in#L607)
we can see the following:

```bash
if [ "${KOPT_s390x_net%%,*}" = "qeth_l2" ]; then
	for mod in qeth qeth_l2 qeth_l3; do
		$MOCK modprobe $mod
	done
	_channel="$(echo ${KOPT_s390x_net#*,} | tr [A-Z] [a-z])"
	echo "$_channel" > /sys/bus/ccwgroup/drivers/qeth/group
	echo 1 > /sys/bus/ccwgroup/drivers/qeth/"${_channel%%,*}"/layer2
	echo 1 > /sys/bus/ccwgroup/drivers/qeth/"${_channel%%,*}"/online
fi
```

So looking at this step by step
the first thing to take out of this is that
the condition defined by:

`"${KOPT_s390x_net%%,*}" = "qeth_l2"`

Has to be met in order to load the `qeth`, `qeth_l2`, `qeth_l3`
modules. This means that in alpine at least in any case we'd
have to specify `s390x_net=qeth_l2`. Before specifying any
ids like `0.0.1000`. Thus writing: `s390x_net=0.0.1000` can't
actually have any effect, even if `qeth_l2` missing wouldn't be the only issue.

the next line is: 

**TODO include kernel source code that made me discover it**

**TODO I think when you echo anything other than 3 ids in there
this failed in the nixos initrd logs dumped to dasd but
confirm it**

`_channel="$(echo ${KOPT_s390x_net#*,} | tr [A-Z] [a-z])"`

which is essentially being stripped from `qeth_l2` before
being written to the ccwgroup+qeth drivers sysfs path like

`echo "$_channel" > /sys/bus/ccwgroup/drivers/qeth/group`

Sadly you can't cat this file to see what the distros provided
by IBM put in there. While the kernel doc actually gives clues
on what this driver is for, before I managed to come across that
a friend once again pointed out that I should give
`s390x_net=qeth_l2,0.0.1000,0.0.1001,0.0.1002` a try.

**TODO [link this](https://www.kernel.org/doc/html/v5.5/s390/driver-model.html#ccwgroup-devices)
or maybe rater this https://docs.kernel.org/driver-api/s390-drivers.html#the-ccwgroup-bus**

So it turns out that unlike seen before with the `dasd=0.0.0100` driver option.
The qeth driver along other networking devices actually consists out of multiple (3x) ccw devices.
One for each channel:

- read
- write
- data

**(^ TODO explain these more indepth)**

IDs are typically handed out in the pattern like seen above.

**TODO show how youd obtain these using tools from s390-tools or
maybe sysfs**

Now after having placed a few values into `/sys/bus/ccwgroup/drivers/qeth/group`
to no success. `echo "0.0.1000,0.0.1001,0.0.1002" > /sys/bus/ccwgroup/drivers/qeth/group`
did finally work. 

The last 2 lines left in alpines init are

```sh
echo 1 > /sys/bus/ccwgroup/drivers/qeth/"${_channel%%,*}"/layer2
echo 1 > /sys/bus/ccwgroup/drivers/qeth/"${_channel%%,*}"/online
```

which are pretty self explainatory if you keep in mind that 
`"${_channel%%,*}"` is just gonna take the first bus id from the 3 ids
passd. Thus `0.0.1000,0.0.1001,0.0.1002` becomes `0.0.1000` and
the resulting path would be just `/sys/bus/ccwgroup/devices/0.0.1000/`.

{% alert(note=true) %}
`/sys/bus/ccwgroup/devices/$ID/` doesn't exist unless you setup
the ccwgroup like explained before. The directory only appears if this
has been done previously. Also as the path only contains one ID in
our case the first one from the 3 setup via qeth's ccwgroup you
can get the impression that there is just `0.0.1000` but actually
`0.0.1001` and `0.0.1002` are involved too.
{% end %}


**TODO also somewhere in here mention that given how on hercules
we didn't have to do the ccwgroup stuff I belived it was fine
to just write one address but confirm this claim**

{% alert(note=true) %}
The Z15 relies on qeth as determined earlier. If networking
was configured on hercules | z/VM's I think you will also end
up having to use qeth. **TODO confirm if z/VM only offers this**
{% end %}


**TODO V strip paths, give credit and explain**

```sh
kexec -l /home/host/TestAndDevel/kexec390/bzImage \
--initrd=/home/host/TestAndDevel/kexec390/initramfs-lts \
--append="ip=192.168.10.106:none:192.168.10.1:255.255.255.0:alpikexec:eth0:none:1.1.1.1:8.8.8.8 alpine_repo=https://dl-cdn.alpinelinux.org/alpine/edge/main modloop=https://dl-cdn.alpinelinux.org/alpine/edge/releases/s390x/netboot/modloop-lts ssh_key=https://raw.githubusercontent.com/cuzrawr/kexec390/refs/heads/main/randssh.key.pub dasd=0.0.0100 s390x_net=qeth_l2,0.0.1000,0.0.1001,0.0.1002
```

>So this should mark the last issue to overcome before we can proceed booting something on the Z15.
Though as booting isn't installing:

## installing NixOS

As we can now boot NixOS in qemu or even on the Z15. The next rational step would be
actually installing it. But to do that we first need a bootloader:

### supporting the zipl booloader on NixOS

Unlike seen with `x86` where there are more bootloaders than let say linux distro families.
S390x / IBM Z doesn't give us a lot to choose from. We got [s390-tools]("https://github.com/ibm-s390-linux/zipl")'s zipl
(Z initial program load)er. Thats it

{% alert(note=true) %}
GRUB2 also supports s390x but as it needs to be loaded from zipl. Thus usually one
does not gain too much by using it. 

(Yes some boot setups benefit from it and I think
suse actually uses that. <small>but then you can also boot into a linux kernel and use
kexec to chainload stuff.

Effectively building your own linux-based bootloader</small>)
**TODO link the article I wrote on linux based bootloaders when I finished it**
{% end %}

Well unlike arch where you would call lets say `grub-install` yourself. Or even
on distros supporting mainframes where you'd call `zipl` in a likewise fashion.

When using NixOS things are a little different. You will not just be required to write a [derivation TODO LINK]("x") but also
a module to go with it. Which is meant to allow NixOS to track the options exposed and thus define
things in an declarative fashion like we are used to when using Nix(OS).

While packaging zipl wasn't the last thing I did, I still put it down here.
I chose this in order to reduce the amount of sections the reader would have to go trough
before getting to see NixOS boot up for the first time.

<small>(I already got it to compile in lxc before even bothering doing
anything beyond what was needed to boot zipl as I really wouldn't
want to put in all this effort to realize I couldn't get zipl working
under nix **which almost was the case**  as you will see :o )</small>

### writing the zipl derivation (compiling it)

[S390-tools]("https://github.com/ibm-s390-linux/zipl") contains a lot of utilities/tools
other than just zipl itself. Some are more or less useless on a NixOS host, some you
can't get around. But as I wanted to initially just focus on zipl I decided to
strip down the makefile <small>(it appears as if there is no way to be particularly selective about the
components you actually want to build)</small>. So I outfitted [my drvs](https://github.com/bolives-hax/nixos-s390x/blob/dbg-fm/pkgs/zipl-package.nix) (TODO link to updated one) `patchPhase`
with:

```sh
substituteInPlace Makefile \
      --replace-fail "LIB_DIRS = libvtoc libzds libdasd libccw libvmcp libekmfweb \\" "LIB_DIRS = #\\" \
      --replace-fail "TOOL_DIRS = zipl zdump fdasd dasdfmt dasdview tunedasd \\" "TOOL_DIRS = zipl dasdfmt netboot zdev#\\"
```

<small>for a quick and hacky yet effective temporary solution</small>

Then I ended up fighting the buildsystem for quite some time to get the dependency checks to
not fail anymore. To hit the first real issue ...

**TODO mention how nix wraps compilers, binutils, and the libc.
Why it does that (like how it injects a bunch of flags)
and why it injecting flags here is a huge problem and not desired**

I didn't expect that id run into any issues that can't aren't essentially
to blame on nix. But here we go: [linker section overlap #171](https://github.com/ibm-s390-linux/s390-tools/issues/171).


{% alert(note=true) %}
By now IBM actually went out of their way to fix this. So any claims made after
this notice no longer apply. But I will still include the parts I wrote before that was the case.
As actually many months passed until [zipl/boot: Increase section size for eckd_mv dumper](https://github.com/ibm-s390-linux/s390-tools/commit/605680d6fdf49807d90b6036d925232ffabaa2c9) fixed it.
{% end %}

While you can read my observations from the issue meant for the folks at IBM. I will still attempt to
break down and simplify the issue a little here as well.

#### linkerscripts

Whats relevant to know about linkerscripts in this context is that
among other things they most importantly tell our compiler(linker) the layout it should
confirm to when "linking" our input files. Its not that common to come across them
unless you work relatively close to hardware and need a higher degree of control
over the binary outputs your compiler produces.

For a bootloader this is of great importance as without an operating system or similar
things around **something** needs to tell it where exactly to place things. For example
lets assume that the hardware loads a certain segment of code into a hardcoded memory
address and then moves execution to it. We'd have to link our executable accordingly.

Of course our program also needs to know the locations of resources required at runtime
like where to find the content of constant variables. Where the stack should be kept
and of corse where the executable sections are. You may even include things such as
headers/metadata which of course also need to be in the right locations.

Linker scripts are meant help with that. Here is an abstract from (s390-tools/zipl's) linker script in question:

```lds
SECTIONS
{
  . = STAGE2_DESC;
  __stage2_desc = .;

  . = STAGE2_LOAD_ADDRESS;
  .stage2.head : { *(.stage2.head) }
  . = STAGE2_ENTRY;
  .text.start : {
    *(.text.start)
  }
  .text : { *(.text) }
  __ex_table_start = .;
  .ex_table : { *(.ex_table) }
  __ex_table_stop = .;
  .rodata : {*(.rodata) }
  .data : { *(.data) }
  __stage2_params = .;

  . = 0x4ff0;
  .stage2dump.tail : { *(.stage2dump.tail) }
  . = 0x5000;
  .eckd2dump_mv.tail : { *(.eckd2dump_mv.tail) }

  . = 0x5200;
  __bss_start = .;
  .bss : { *(.bss) }
  __bss_stop = .;

  . = STAGE2_HEAP_ADDRESS;

  ...
  ...
  ...
}
```

for example the following sections have the following functions:

- `.text` <small>yes .text (this has nothing to do with ascii text)</small>
traditionally contains out executable code. As in the actual opcodes/machine code.

- `.rodata` contains static variables, be it global or local if they are static they
are "ro"="read only" and are put here

- `.bss` (block statring symbol) contains statically allocated variables. But unlike
`.rodata` these are merely allocated meaning they haven't been assigned values yet
as that happens at runtime.

- `.data` think `.rodata` except that its rw as in "read/write"-able

The actual layout (that was causing me issues) looks like this:

```
/*
 * Memory layout of stage 2 for ECKD DASD dump tool
 * (single volume and multi volume)
 * ===============================================
 *
 * General memory layout
 * ---------------------
 *
 * 0x0000-0x1fff	Lowcore
 * 0x2000-0xafff	Sections (load): head, text, data, rodata, rodata.str,
 *			stage2dump.tail, eckd2dump_mv.tail, bss
 * 0xb000-0xdfff	Memory allocation (heap)
 * 0xe000-0xffff	Stack
 *
 * Special memory locations
 * ------------------------
 *
 * 0x78			Stage 2 description parameters
 * 0x2018		Stage 2 entry point
 * 0x4ff0		Stage 2 multi-volume dump parameters (eckd2dump_mv)
 * 0x5000		Multi-volume dump parameters table (eckd2dump_mv)
 * 0x9ff0		Stage 2 single volume dump parameters (eckd2dump_sv)
 */
```

In the linkerscript abstract shown above there is on line thats of particular interest
to us. And its `. = 0x4ff0;` followed by `.stage2dump.tail : { *(.stage2dump.tail) }`.

So as the comment describing the layout in a human readable fashion
states `0x2018 Stage 2 entry point` and `0x4ff0	Stage 2 multi-volume dump parameters (eckd2dump_mv)`.
We can say that at `0x2018` stage 2 pickups execution leaving space up until `0x4ff0` where
the multi volume dump parameters are located. Thus `0x4ff0 - 0x2018 = 0x2fd8` gives us
`11248 bytes` of space to place our executable code before another non executable section
follows.

#### whats the problem (and why did I run into it)?

What needs to be said here is as I wanted to run this on the Z10, I chose to
compile it with the Z10's (cpu) set as the target. (As opposed to z13-z16 which are whats commonly
used at the time of writing this). The problem though is that quoting [sharkcz's comment](https://github.com/ibm-s390-linux/s390-tools/issues/171#issuecomment-2258137192)

<q>in Fedora we are now at z13 as the arch level, we were on zEC12 for a long time and on z10 before that"</q>

with the last z10 being from 2008 its safe to assume that development is most likely done on
Z13 or even Z15 as IBM operates a Z15 for selected open source projects to use. Even I do so. But
unlike the other devs I guess what sets me apart from them is wanting to run this on the Z10
as that is the machine I actually have sitting around locally.

<small>Running things on real hardware. Sitting right in front of you remains special in my eyes.
Cloud services lack this magical feeling real hardware provides :3</small>

But how does this now play into the issue? Wouldn't zipl compile just fine for the Z10? There shouldn't
really anything explicitly preventing it. While many more features got added none of them
appear to explicitly be incompatible with the Z10 architecture. 

The issue is much simpler. Its not a specific
feature rather its that there are **"many features"** now resulting in more code to be compiled
and consequently more machine code to be emitted.

Now remember the fact that we "only" got `11248 bytes`. But that still doesn't answer why this works for the Z13-Z15.
Well the thing is while the size limit remains the same for every IBM Z series mainframe. The
compilers `-march=` optimisation flag does have a bigger and bigger effect when compiling with
`-Os` / `-Oz` optimizing for size. With s390x being a 
[cisc architecture](https://github.com/ibm-s390-linux/s390-tools/issues/171#issuecomment-2258137192)and more and more
instructions being added. The compiler can naturally generate smaller and smaller binaries.
Because imagine you can do some sort of cpu operation that would have required lets say 20 (or even 200) instructions in the
same space as 1 to 10.

Thats the issue at core here.

**TODO show diffs proving my point**

### well what now?

While trying out various compiler flags, compiler versions and even clang/LLVM <small>(because why not)</small>
I got a little lucky. Turns out that when using gcc14 paired with the `gcc.arch = "z10";` flag. Things
would actually compile. Making the Z10 I guess the oldest mainframe one could build s390-tools zipl for
<small>(and luckily that was the one I was targetting)</small>.

Its of advantage that nix(pkgs) makes it somewhat trivial to swap out the version GCC used by `stdenv.mkDerivation {}`. It
does this by offering a bunch of packages
with the following namingscheme <q>gcc`<MAJOR_VERSION_NUMBER>`Stdenv</q>. As packages providing an `stdenv`
expose `.mkDerivation {}` which is what we want to build pretty much everything in nix.

Using the following did the trick:

```nix
{
    packages.s390x_linux.default = pkgs.gcc14Stdenv.mkDerivation {
        name = "s390-tools";
        # ...
    };
}
```

**(TODO after fixing the actual zipl drv include a proper snippet though it more or less says this either way)**

{% alert(tip=true) %}
Using multiple stdenv packages `mkDerivation {}` function will result
in having to compile it from scratch if you don't have binary caches. This is often the case on
niche architectures or when using custom compiler flags with your nixpkgs.

Among other reasons, this is why using multiple `stdenv`'s is not exactly favorable. Especially if
you will only do that for a single package <small>(unlike using a certain gcc version is unavoidable like in my case until IBM's fix</small>)

{% end %}

So with my initial crude attempts at writing the "s390-tools => (zipl)" derivation
now actually building succesfully for the first time. Its time for the next stage:


<small>(gotta come back here some day to bring this derivation out of this hacky state its in but let that be my problem)</small>

### going from zipl to `boot.loader.zipl`:

If you ever succesfully installed nixos before you probably remember having used an option starting with `boot.loader` like
`boot.loader.grub` or `boot.loader.systemd-boot` or even `boot.loader.generic-extlinux-compatible` (<small>assuming of course
you did not use the installer which seems to exist these days</small>)

#### Though what would need to be done to get `boot.loader.zipl` to show up in here as well?

In order for the module to work like the other bootloaders it needs to declare a single setting: `system.build.installBootLoader`
<small>(and maybe `system.boot.loader.id = "zipl";` but that one is boring)</small> **TODO confirm if loader.id is needed I forgot**

This is as when `nixos-install` is being run (or `nixos-rebuild` for this matter) it will evaluate this specific option
and at some point during the rebuild/install process execute whatever this option points to. All bootloaders I've seen
packaged so far bring some sort of wrapper script.

Grub for example has: [nixos/modules/system/boot/loader/grub/install-grub.pl](https://github.com/NixOS/nixpkgs/blob/5135c59491985879812717f4c9fea69604e7f26f/nixos/modules/system/boot/loader/grub/install-grub.pl).

And extlinux has: [nixos/modules/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.sh](https://github.com/NixOS/nixpkgs/blob/5135c59491985879812717f4c9fea69604e7f26f/nixos/modules/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.sh). 

Besides the fact that I don't know the perl language the `extlinux-conf-builder.sh` helper script is also much simpler. So lets look at this
one as opposed to `install-grub.pl` .

From simply looking at the way its invoked its pretty clear what we will have to do something like:

```sh
export PATH=/empty:@path@

usage() {
    echo "usage: $0 -t <timeout> -c <path-to-default-configuration> [-d <boot-dir>] [-g <num-generations>] [-n <dtbName>] [-r]" >&2
    exit 1
}

timeout=                # Timeout in centiseconds
menu=1                  # Enable menu by default
default=                # Default configuration
target=/boot            # Target directory
numGenerations=0        # Number of other generations to include in the menu

# ...
# actual implementation
# ...
```

<small>For now just assume `$PATH` is properly populated with all the executables we need</small> 

You can see that the helper script is merely being called with a bunch of parameters. Just two of these **have to** be provided:
namely `-t timeout` and `-c path-to-default-configuration`. But all the other ones are optional | may have a default
value assigned if unspecified. 

While most of these settings are quite useful and should be supported **in theory** `-c`
would be the only option you to respect. The `-c` doesn't come from the nixos activation scripts though
as they wrapped it a tiny bit in reality it looks 
like this 
```sh
${builder} ${builderArgs} -d '${args.path}' -c "$@"

```
So `$@` is actually whats being passed rather than `-c <value>`

Thus its "the **first** commandline argument" passed to the executable declared by `system.build.installBootLoader` that
defines the path this script should install the bootloader files to.

The way one would want to wrap this and maybe processes further parameters,
depends on the features your bootloader actually supports and consequently the the module options you exposed
<small>(the menu bootentry selection timeout is a good example)</small>.

<small>
{% alert(note=true) %}
grub supports **A LOT** of features which is probably why it needs a huge perl script as opposed to the shell based extlinux-compat shown above
{% end %}
</small>

So to write a bootloader module one essentially only has to respect the installation path and ideally expose every
functionality/feature the bootloader configs offer trough the nixos option system. And consequently parse the flags
you fed to your helper script trough the commandline parameters/env given.

So the skeleton I ended up using looks something like this:

```nix
{config,pkgs,lib,...}: let
  builder = pkgs.substituteAll {
    src = ./zipl-conf-builder.sh;
    isExecutable = true;
    path = with pkgs; [
      coreutils
      gnused
      gnugrep
      s390-tools # zipl is found here
    ];
    inherit (pkgs) bash;
  };
in {
  options = {
      boot.loader.zipl = {
          enable = mkOption {
              default = false;
              type = types.bool;
              description = "wether to enable s390-tools zipl bootloader";
          };

          /* other options here like:
          timeout = mkOption { ... }; 
          
          to then append below in between ${builder} and -c
          */
      };
  };

  config = mkIf config.boot.loader.zipl.enable {
      system.build.installBootLoader = "${builder} -c";
      system.boot.loader.id = "zipl";
  };
} 
```

other than `pkgs.substituteAll` wich takes care of the conf-builders `$PATH` variable being properly
populated. Everything seen above should have been covered by now. The script itself won't
structurally and conceptually differ <small>(toooo much)</small> from the extlinux one. Except
that in my case boot loader menu entries and the actual
entries are being organized into 2 different blocks that are later on merged together. 

Because one of nixos's greatest feature is being able to switch between system-generations
(ideally directly from the bootloader) to temporarily roll back broken systems and such without
relying on CoW filesystems or such things. One most likely wants to add support fot that in ones
script as well. Thus a little funky shell magic is needed:


```sh
    for generation in $(
            (cd /nix/var/nix/profiles && ls -d system-*-link) \
            | sed 's/system-\([0-9]\+\)-link/\1/' \
            | sort -n -r \
            | head -n $numGenerations); do
        link=/nix/var/nix/profiles/system-$generation-link
        addZiplEntry $link "${generation}" >> $tmpFile

        for specialisation in $(
            ls /nix/var/nix/profiles/system-$generation-link/specialisation \
            | sort -n -r); do
            link=/nix/var/nix/profiles/system-$generation-link/specialisation/$specialisation
            addZiplEntry $link "${generation}-${specialisation}" >> $tmpFile
        done
    done
```

while a little simplified and still WIP / subjected to change. addZiplEntry effectively
- add a menu option to the zipl config file
- extracts the profiles init= and other kernel parameters
- copies over the profiles kernel and initrd to the bootloader install dir
- is able to also perform cleanup on kernels/initrds if the generation was to be removed
- actually installs zipl `zipl --config=` with the newly generated config


## booting NixOS (IBM Z10)

**TODO link to secondary article that explains how
to even set up a mainframe (as in sitting in front of it)**

---

## etc : 



I also needed to address issues in pythons psutil,numpy1,numpy2 when building a more common NixOS installation, it is also required to do some modifications to libfuse,libuv,klibc,spdlog,luajit,libopus,tmp2-tss,aws-c-sdk,aws-c-common. 


Also to have a more or less proper nixos system one may not get around the fact that nsncd has some serialization issues and netcat needs to be 
taken from openssl not libressl as libressl completely dropped s390x support in recent years. 

Also the tpm2 systemd service being broken and some kernel flags being absent is something to keep in mind.
**TODO maybe elaborate on all of these points**



TODO talk about https://github.com/aws/aws-sdk-cpp 
