{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
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
        pythonWithPackages = pkgs.python311.withPackages (ps: with ps; [
          (west.overridePythonAttrs (super: {
            propagatedBuildInputs = super.propagatedBuildInputs ++ [ pyelftools ];
          }))
        ]);
        packages = with pkgs; [
          yosys
          nextpnr
          trellis ghdl
          dfu-util
          riscv_toolchain_prebuilt
          cmake gnumake
          zephyrSdk pythonWithPackages ninja
          git
        ];
      in {
        devShells.default = pkgs.mkShellNoCC {
          nativeBuildInputs = packages;
          shellHook = ''
            export PS1="(TwPM) $PS1"
            export TWPM_ZEPHYR_CMAKE_PATH=${zephyrSdk}/cmake
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
