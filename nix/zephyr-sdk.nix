{ stdenv, lib, zlib, libmpc, gmp, mpfr, patchelf, makeWrapper, python311, ... }:
stdenv.mkDerivation rec {
  pname = "zephyr-sdk";
  version = "0.16.3";
  src = builtins.fetchurl {
    url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${version}/zephyr-sdk-${version}_linux-x86_64.tar.xz";
    sha256 = "9eb557d09d0e9d4e0b27f81605250a0618bb929e423987ef40167a3307c82262";
  };
  outputs = ["unwrapped" "out"];
  nativeBuildInputs = [ patchelf makeWrapper ];
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
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ zlib libmpc gmp mpfr ]}"
      fi
    done
  '';
}
