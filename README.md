# TwPM_toplevel

This repository combines all pieces of TwPM code into one build target. For more
info about TwPM project go to [TwPM's official site](https://twpm.dasharo.com/).

## Cloning

This repository contains just a bit of glue code and some Makefiles. All of the
real code lives in other repositories included as submodules, be sure to clone
them as well:

```shell
$ git clone https://github.com/Dasharo/TwPM_toplevel.git
$ cd TwPM_toplevel
$ git submodule update --init --checkout
```

## Build environment

All components are expected to be build within Nix shell. If you haven't got
Nix installed yet, follow [official installation instructions](https://nixos.org/download#nix-install-linux).

## Starting Nix shell

Shell can be started by typing:

```shell
nix develop
```

Nix will automatically download all packages and launch shell. Packages from
Host OS will still be available. If you want to start a clean environment you
can do:

```shell
nix-shell --pure $(nix build --no-link --json .#devShells.x86_64-linux.default | jq -r '.[].drvPath')
```

Please note that all commands executed from Nix shell are running on host.

## Building - easy

> Here will be description of how to build whole project with one command, when
> it will be ready.

## Building - advanced

Components of TwPM may also be built separately. Such approach is most useful
to developers and [hackers](https://en.wikipedia.org/wiki/Hacker_culture) to
quickly test modified code without having to build everything from scratch.

Note that if you already have built whole project earlier, `make` should be able
to detect which components have changed and rebuild only those. In that case you
can follow [the easy path](#building---easy).

### MCU

> TBD: description of building and hacking TPM stack and platform glue code.

### FPGA

To just build:

```shell
$ cd fpga
$ make
```

This will execute all steps up to and including generation of bitstream.

To build and flash:

```shell
$ cd fpga
$ dfu-util -D build/twpm.dfu
```

## Funding

This project was partially funded through the
[NGI Assure](https://nlnet.nl/assure) Fund, a fund established by
[NLnet](https://nlnet.nl/) with financial support from the European
Commission's [Next Generation Internet](https://ngi.eu/) programme, under the
aegis of DG Communications Networks, Content and Technology under grant
agreement No 957073.

<p align="center">
<img src="https://nlnet.nl/logo/banner.svg" height="75">
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<img src="https://nlnet.nl/image/logos/NGIAssure_tag.svg" height="75">
</p>
