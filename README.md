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

This environment is still running on your host. If you want clean and isolated
environment you can use Docker or Podman to create isolated environment:

```shell
nix run .#sdk.copyToDockerDaemon
```

> Note: [skopeo](https://github.com/containers/skopeo) (the tool that is used
> internally for copying image to Docker) does not work with Docker newer than
> 25.0.0 due to [#2202](https://github.com/containers/skopeo/issues/2202). Until
> this is solved, you can use the following workaround:
>
> ```shell
> nix run .#sdk.copyTo -- docker-archive:sdk.tar:twpm-sdk:latest
> docker load < sdk.tar
> rm sdk.tar
> ```

or for Podman:

```shell
nix run .#sdk.copyToPodman
```

Both commands will print name of container:

```
Copy to Docker daemon image twpm-sdk:40hahn4y8k477rhn006fx524463vkaag
Getting image source signatures
Copying blob 3250b1004e0f done
Copying config 004a96a585 done
Writing manifest to image destination
```

To run container do:

```shell
docker run --rm -it --mount type=tmpfs,destination=/tmp \
    -v $PWD:/work -w /work -u $(id -u):$(id -g) \
    twpm-sdk:40hahn4y8k477rhn006fx524463vkaag
```

> If you to want to flash device from container you must start it in privileged
> mode and give access to USB:
> ```shell
> docker run --privileged -v /dev/bus/usb:/dev/bus/usb --rm -it \
>   --mount type=tmpfs,destination=/tmp -v $PWD:/work -w /work \
>   -u $(id -u):$(id -g) twpm-sdk:40hahn4y8k477rhn006fx524463vkaag
> ```

## Setting up UDev

If you want to flash device without `sudo` add this to
`/etc/udev/rules.d/90-orangecrab.rules`

```
ACTION=="add|change", ATTRS{idVendor}=="1209", ATTRS{idProduct}=="5af0", OWNER="<enter_your_user_name_here>"
```

> Remember to replace `<enter_your_user_name_here>` with your username.

After creating `.rules` file type

```shell
udevadm control --reload-rules
```

for changes to take effect.

## Building - easy

To build everything at once start TwPM SDK environment as described in the
section above and type:

```
make
```

## Building - advanced

Components of TwPM may also be built separately. Such approach is most useful
to developers and [hackers](https://en.wikipedia.org/wiki/Hacker_culture) to
quickly test modified code without having to build everything from scratch.

Note that if you already have built whole project earlier, `make` should be able
to detect which components have changed and rebuild only those. In that case you
can follow [the easy path](#building---easy).

### MCU

> TBD: description of building and hacking TPM stack and platform glue code.

### Programmming FPGA bitstream

To flash firmware enter bootloader mode on OrangeCrab by connecting USB while
holding on-board button pressed.

Then type:

```shell
$ dfu-util -D build/fpga/twpm.dfu
```

### Connecting UART

UART is accessible on following pins

| Pin | Function |
| --- | -------- |
| GND | Ground   |
| 0   | TX       |
| 1   | RX       |

UART is configured to run at *115200n8* (115200 baud rate, 8 data bits, 1 stop
bit, parity off, flow control off).

To connect do

```shell
minicom -D /dev/ttyUSB0 -b 115200
```

> Make sure you have UART configured properly: while in Minicom press *Ctrl+A O*,
> go to *Serial Port Setup* menu, make sure that *Flow Control* is disabled,
> and make sure data bits, stop bits and parity is configured properly.

### Uploading TwPM firmware trough UART

> Currently firmware must be uploaded through UART as there is no support for
> booting from SPI yet.

Connect UART as described in the section above. Make sure you have programmed
the bitstream already.

After powering-on the board you will greated by NEORV32 bootloader:

```
<< NEORV32 Bootloader >>

BLDV: Nov 24 2023
HWV:  0x01090007
CLK:  0x03010b00
MISA: 0x40801105
XISA: 0x00000c83
SOC:  0x80878003
IMEM: 0x00010000
DMEM: 0x00010000

Autoboot in 3s. Press any key to abort.
Aborted.

Available CMDs:
 h: Help
 r: Restart
 u: Upload
 s: Store to flash
 l: Load from flash
 e: Execute
CMD:>
```

Press immediately any key to interrupt autoboot process, then press *u* to enter
upload mode.

From another terminal type:

```shell
dd if=build/firmware/zephyr_with_header.bin of=/dev/ttyUSB0
```

> `/dev/ttyUSB0` is the same UART on which Minicom is running and this command
> *must* be executed while Minicom is running.

When update is complete press *e* to boot. After few seconds you should be
greated by TwPM firmware.

That's how full boot log looks like:

```
<< NEORV32 Bootloader >>

BLDV: Nov 24 2023
HWV:  0x01090007
CLK:  0x03010b00
MISA: 0x40801105
XISA: 0x00000c83
SOC:  0x80878003
IMEM: 0x00010000
DMEM: 0x00010000

Autoboot in 3s. Press any key to abort.
Aborted.

Available CMDs:
 h: Help
 r: Restart
 u: Upload
 s: Store to flash
 l: Load from flash
 e: Execute
CMD:> u
Awaiting neorv32_exe.bin... OK
CMD:> e
Booting from 0x80000000...

*** Booting Zephyr OS build 71194e41ac04 ***
[00:00:00.005,000] <inf> main: Starting TwPM on orangecrab
[00:00:00.006,000] <wrn> nv: TwPM was built with CONFIG_TWPM_NV_EMULATE. Changes are NOT persistent!
[00:00:02.904,000] <inf> nv: NV commit
[00:00:02.905,000] <inf> init: TPM manufacture OK
[00:00:04.599,000] <inf> nv: NV commit
[00:00:04.601,000] <inf> test: TPM command result: {TPM_RC_SUCCESS}
[00:00:04.723,000] <inf> nv: NV commit
[00:00:04.734,000] <inf> test: HASH: 12f411d0eebfb9c4d81df9f1cb10e22e9841a91428ea7f00969fa7f29db0f7fa
```

### Building with Lattice Diamond

> Diamond has been used only for development purposes and is not tested as
> widely as Trellis toolchain.

Lattice Diamond is a proprietary synthesis tool, the tool is available for free,
however it requires account registration to obtain license. TwPM FPGA design can
be synthesized using Diamond by doing:

```shell
make FPGA_TOOLCHAIN=diamond
```

Diamond is available through Nix as part of TwPM SDK extension, to launch shell
with Diamond installed type:

```shell
nix develop .#with-diamond
```

When using Docker/Podman type:

```shell
nix run .#sdk-diamond.copyToDockerDaemon
```

Diamond will check MAC address of NIC so you need to run with `--network=host`
for license to work. When inside shell set `LM_LICENSE_FILE` environment
variable.

Diamond GUI can be launched using

```
nix run .#diamond
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
