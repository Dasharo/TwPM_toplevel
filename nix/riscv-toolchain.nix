{ stdenv, lib, zlib, libmpc, gmp, mpfr, patchelf, makeWrapper, ... }:
stdenv.mkDerivation {
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
  nativeBuildInputs = [ patchelf makeWrapper ];
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
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ zlib libmpc gmp mpfr ]}"
      fi
    done
  '';
}
