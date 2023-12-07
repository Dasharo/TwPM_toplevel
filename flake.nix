{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    litex = {
      url = "github:enjoy-digital/litex/2023.08";
      flake = false;
    };
    migen = {
      url = "github:m-labs/migen/0.9.2";
      flake = false;
    };
    valentyusb = {
      url = "github:litex-hub/valentyusb/hw_cdc_eptri";
      flake = false;
    };
    litedram = {
      url = "github:enjoy-digital/litedram/2023.08";
      flake = false;
    };
    litex-boards = {
      url = "github:litex-hub/litex-boards";
      flake = false;
    };
    pythondata-cpu-vexriscv = {
      url = "https://github.com/litex-hub/pythondata-cpu-vexriscv";
      flake = false;
      type = "git";
      submodules = true;
    };
    pythondata-software-picolibc = {
      url = "https://github.com/litex-hub/pythondata-software-picolibc";
      flake = false;
      type = "git";
      submodules = true;
    };
    pythondata-software-compiler_rt = {
      url = "https://github.com/litex-hub/pythondata-software-compiler_rt";
      type = "git";
      flake = false;
      submodules = true;
    };
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Prebuilt Risc-V toolchain is available only for x86_64
      systems = [ "x86_64-linux" ];
      perSystem = { config, pkgs, system, ... }:
      let
        nix2container = inputs.nix2container.packages.${system}.nix2container;
        riscv_toolchain_prebuilt = pkgs.stdenv.mkDerivation {
        name = "riscv_toolchain_prebuilt";
        src = builtins.fetchurl {
          url = "https://github.com/stnolting/riscv-gcc-prebuilt/releases/download/rv32i-131023/riscv32-unknown-elf.gcc-13.2.0.tar.gz";
          sha256 = "sha256:1kph2i3jip8pi595fn1svq9ijnrpsssg68hqg4iazpdmmqjlpjkr";
        };
        outputs = [ "out" "unwrapped" ];
        unpackPhase = ''
          mkdir -p $unwrapped
          tar xf $src -C $unwrapped
        '';
        nativeBuildInputs = with pkgs; [ patchelf makeWrapper ];
        installPhase = ''
          for file in $(find $unwrapped); do
            if file $file | grep -qE 'ELF.*executable.*interpreter'; then
              patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                $file
            fi
          done

          mkdir -p $out/bin

          cd $unwrapped/bin
          for file in *; do
            if [ -x $file ]; then
              makeWrapper "$unwrapped/bin/$file" "$out/bin/$file" \
                --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath (with pkgs; [ zlib libmpc gmp mpfr ])}"
            fi
          done
        '';
        };
        zephyrSdk = pkgs.stdenv.mkDerivation rec {
          pname = "zephyr-sdk";
          version = "0.16.3";
          src = builtins.fetchurl {
            url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${version}/zephyr-sdk-${version}_linux-x86_64.tar.xz";
            sha256 = "9eb557d09d0e9d4e0b27f81605250a0618bb929e423987ef40167a3307c82262";
          };
          outputs = ["unwrapped" "out"];
          nativeBuildInputs = with pkgs; [ patchelf makeWrapper ];
          unpackPhase = ''
            tar xf $src \
              zephyr-sdk-${version}/riscv64-zephyr-elf \
              zephyr-sdk-${version}/cmake \
              zephyr-sdk-${version}/sdk_version
          '';
          installPhase = ''
            mkdir $out
            mkdir $unwrapped
            mv zephyr-sdk-${version}/riscv64-zephyr-elf $unwrapped/
            mv zephyr-sdk-${version}/cmake $out/
            mv zephyr-sdk-${version}/sdk_version $out/
            echo "riscv64-zephyr-elf" > $out/sdk_toolchains

            for file in $(find $unwrapped); do
              if file $file | grep -qE 'ELF.*executable.*interpreter'; then
                patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                  $file
              fi
            done

            mkdir -p $out/riscv64-zephyr-elf/bin
            cd $unwrapped/riscv64-zephyr-elf/bin
            for file in *; do
              if [ -x $file ]; then
                makeWrapper "$unwrapped/riscv64-zephyr-elf/bin/$file" "$out/riscv64-zephyr-elf/bin/$file" \
                  --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath (with pkgs; [ zlib libmpc gmp mpfr ])}"
              fi
            done
          '';
        };
        inherit (pkgs.python310Packages) buildPythonPackage;
        litex = buildPythonPackage rec {
          pname = "litex";
          version = inputs.litex.shortRev;
          src = inputs.litex;
          doCheck = false;
          postPatch = ''
            substituteInPlace litex/soc/software/common.mak \
              --replace "PYTHON ?= python3" "PYTHON ?= \$(NIX_LITEX_PYTHON_PATH)"
          '';
          propagatedBuildInputs = [
            (buildPythonPackage {
              pname = "migen";
              version = inputs.migen.shortRev;
              src = inputs.migen;
              doCheck = false;
              propagatedBuildInputs = with pkgs.python310Packages; [
                colorama
              ];
            })
          ];
        };
        litex-boards = buildPythonPackage rec {
          pname = "litex-boards";
          version = inputs.litex-boards.shortRev;
          src = inputs.litex-boards;
          doCheck = false;
          propagatedBuildInputs = [ litex ];
        };
        valentyusb = buildPythonPackage {
          pname = "valentyusb";
          version = inputs.valentyusb.shortRev;
          src = inputs.valentyusb;
          doCheck = false;
          propagatedBuildInputs = [
            litex
          ];
        };
        litedram = buildPythonPackage {
          pname = "litedram";
          version = inputs.litedram.shortRev;
          src = inputs.litedram;
          doCheck = false;
          propagatedBuildInputs = [
            litex
          ];
        };
        pythondata-cpu-vexriscv = buildPythonPackage {
          pname = "pythondata-cpu-vexriscv";
          version = inputs.pythondata-cpu-vexriscv.shortRev;
          src = inputs.pythondata-cpu-vexriscv;
          doCheck = false;
          propagatedBuildInputs = [
            litex
          ];
        };
        pythondata-software-picolibc = buildPythonPackage {
          pname = "pythondata-software-picolibc";
          version = inputs.pythondata-software-picolibc.shortRev;
          src = inputs.pythondata-software-picolibc;
          doCheck = false;
          propagatedBuildInputs = [
            litex
          ];
        };
        pythondata-software-compiler_rt = buildPythonPackage {
          pname = "pythondata-software-compiler_rt";
          version = inputs.pythondata-software-compiler_rt.shortRev;
          src = inputs.pythondata-software-compiler_rt;
          doCheck = false;
          propagatedBuildInputs = [
            litex
          ];
        };
        pythonWithPackages = pkgs.python310.withPackages (ps: with ps; [
          (west.overridePythonAttrs (super: {
            propagatedBuildInputs = super.propagatedBuildInputs ++ [ pyelftools ];
          }))
          litex litex-boards litedram
          valentyusb
          pythondata-cpu-vexriscv pythondata-software-picolibc pythondata-software-compiler_rt
          meson
        ]);
        diamond = pkgs.stdenv.mkDerivation rec {
          pname = "diamond";
          version = "3.13";

          src = builtins.fetchurl {
            url = "https://files.latticesemi.com/Diamond/3.13/diamond_3_13-base-56-2-x86_64-linux.rpm";
            sha256 = "1li9yvgd3zamijb8l7jaq663qxn5vamr95y1b5ig342nxvd8g9yg";
          };

          nativeBuildInputs = with pkgs; [ rpmextract patchelf makeWrapper ];
          outputs = [ "unwrapped" "out" ];

          unpackPhase = ''
            mkdir $unwrapped
            cd $unwrapped
            rpmextract $src
            mv usr/local/diamond/${version} diamond
            rm -rf usr

            cd $unwrapped/diamond/bin
            tar xf bin.tar.gz && rm bin.tar.gz

            cd $unwrapped/diamond/cae_library
            tar xf cae_library.tar.gz && rm cae_library.tar.gz

            cd $unwrapped/diamond/data
            tar xf data.tar.gz && rm data.tar.gz

            cd $unwrapped/diamond/embedded_source
            tar xf embedded_source.tar.gz && rm embedded_source.tar.gz

            cd $unwrapped/diamond/examples
            tar xf examples.tar.gz && rm examples.tar.gz

            cd $unwrapped/diamond/ispfpga
            tar xf ispfpga.tar.gz && rm ispfpga.tar.gz

            cd $unwrapped/diamond/modeltech
            tar xf modeltech.tar.gz && rm modeltech.tar.gz

            cd $unwrapped/diamond/synpbase
            tar xf synpbase.tar.gz && rm synpbase.tar.gz

            cd $unwrapped/diamond/tcltk
            tar xf tcltk.tar.gz && rm tcltk.tar.gz
          '';

          installPhase = ''
            for file in $(find $unwrapped); do
              if file $file | grep -qE 'ELF.*executable.*interpreter'; then
                patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                  $file
              fi
            done

            mkdir $out
            cd $out

            mkdir bin
            for file in {diamond,diamondc}; do
              makeWrapper "$unwrapped/diamond/bin/lin64/$file" "$out/bin/$file" \
                    --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath (with pkgs; [
                        glibc
                        glib
                        zlib
                        freetype fontconfig.lib
                        xorg.libX11 xorg.libSM xorg.libICE xorg.libXext xorg.libXrender xorg.libXt xorg.libXcomposite
                        libuuid libkrb5 libglvnd libxml2
                        gst_all_1.gstreamer gst_all_1.gst-plugins-base
                        sqlite graphite2
                      ])}"
            done
          '';
        };
        packages = with pkgs; [
          yosys
          nextpnr
          trellis ghdl
          dfu-util
          riscv_toolchain_prebuilt
          cmake gnumake
          zephyrSdk pythonWithPackages ninja
          git
          diamond
          valgrind gdb strace ltrace
        ];
      in {
        devShells.default = pkgs.mkShellNoCC {
          nativeBuildInputs = packages;
          shellHook = ''
            export PS1="(TwPM) $PS1"
            export TWPM_ZEPHYR_CMAKE_PATH=${zephyrSdk}/cmake
            export NIX_LITEX_PYTHON_PATH=${pythonWithPackages}/bin/python3
          '';
        };
        packages.sdk = let
          containerBasePackages = with pkgs; [
            bashInteractive
            coreutils
            findutils
            gnugrep
            gnused
            gcc
          ];
          containerInit = pkgs.writeShellScript "twpm-container-init" ''
            export PATH="${pkgs.lib.makeBinPath (containerBasePackages ++ packages)}"
            export PS1="(TwPM) $PS1"

            mkdir /tmp &>/dev/null || true

            export TWPM_ZEPHYR_CMAKE_PATH=${zephyrSdk}/cmake
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            exec bash -i
          '';
        in nix2container.buildImage {
          name = "twpm-sdk";
          copyToRoot = [
            (pkgs.buildEnv {
              name = "root";
              paths = [
                (pkgs.runCommand "root" {} ''
                  # Link bash to /bin
                  # This workarounds problem with yosys unable to spawn ABC
                  # and gives possibility to exec shell in container without
                  # needing to know full Nix store path.
                  mkdir -p $out/bin
                  cd $out/bin
                  ln -s ${pkgs.bashInteractive}/bin/bash .
                  ln -s ${pkgs.bashInteractive}/bin/sh .
                '')
              ];
              pathsToLink = [ "/bin" "/lib64" ];
            })
          ];
          config = {
            entrypoint = [
              "${pkgs.bashInteractive}/bin/bash"
              "-i"
              containerInit
            ];
          };
        };
      };
    };
}
