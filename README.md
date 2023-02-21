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

## Docker image

All components are expected to be build within Docker container. If you haven't
got Docker installed yet, follow [official installation instructions](https://docs.docker.com/engine/install/)
and [post-installation steps](https://docs.docker.com/engine/install/linux-postinstall/).

TwPM Docker image is created from [Dockerfile](https://github.com/Dasharo/TwPM_toplevel/blob/main/Dockerfile)
that is included in this repository. As of now, this image isn't available for
download and must be built locally with the following command executed from the
`TwPM_toplevel` directory:

```shell
$ docker build -t twpm-sdk .
```

Go grab a cup of tea or your favourite beverage, this will take a while. Image
preparation ends with `Successfully tagged twpm-sdk:latest`.

> This image probably will eventually be available at ghcr.io, but for now it is
still being actively worked on and will change significantly. For the same
reason the image isn't versioned yet.

The container can be started from `TwPM_toplevel` with:

```shell
$ docker run --rm -it -v $PWD:/home/qorc-sdk/workspace twpm-sdk
```

This will enable `qorc-sdk` environment and enter shell in the container:

```
=========================
qorc-sdk envsetup 1.5.1
=========================


executing envsetup.sh from:
/home/qorc-sdk/qorc-sdk

[1] check (minimal) qorc-sdk submodules
    ok.

[2] check arm gcc toolchain
    initializing arm toolchain.
    ok.

[3] check fpga toolchain
    initializing fpga toolchain.
    ok.

[4] check flash programmer
    initializing flash programmer.
    ok.

[5] check openocd
    ok.

[6] check jlink
    ok.


qorc-sdk build env initialized.


(base) qorc-sdk@2fb0c54fd594:~$
```

All of the following steps assume that we are in this state - inside the Docker
container with `qorc-sdk` environment enabled, in container's home directory.

## Building - easy

> Here will be description of how to build whole project with one command, when
it will be ready.

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

```shell
$ cd workspace/fpga
$ make
```

This will execute all steps up to and including generation of bitstream. This
process takes few minutes, most of that time is consumed by `symbiflow_route`.
It may appear to be stuck, as this process doesn't output any lines on terminal.
It also almost doesn't access disk at all, but it takes a lot of CPU time.

