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
        riscv_toolchain_prebuilt = pkgs.stdenvNoCC.mkDerivation {
        name = "riscv_toolchain_prebuilt";
        src = builtins.fetchurl {
          url = "https://github.com/stnolting/riscv-gcc-prebuilt/releases/download/rv32i-131023/riscv32-unknown-elf.gcc-13.2.0.tar.gz";
          sha256 = "sha256:1kph2i3jip8pi595fn1svq9ijnrpsssg68hqg4iazpdmmqjlpjkr";
        };
        unpackPhase = ''
          mkdir -p $out
          tar xf $src -C $out
        '';
        };
        packages = with pkgs; [
          yosys
          nextpnr
          trellis ghdl
          dfu-util
          riscv_toolchain_prebuilt
        ];
      in {
        devShells.default = pkgs.mkShellNoCC {
          nativeBuildInputs = packages;
          shellHook = ''
            export PS1="(TwPM) $PS1"
          '';
        };
      };
    };
}
