{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./nix/container.nix
      ];
      # Prebuilt Risc-V toolchain is available only for x86_64
      systems = [ "x86_64-linux" ];
      perSystem = { self', pkgs, system, ... }:
      let
        inherit (pkgs) stdenv lib;

        packages = with pkgs; [
          yosys nextpnr trellis ghdl dfu-util
          self'.packages.riscv-toolchain-prebuilt
          self'.packages.zephyr-sdk self'.packages.west
          ninja
          cmake gnumake
          git
        ];
        sdk-base = pkgs.writeScript "twpm-sdk-init" ''
          export PS1="(TwPM) $PS1"
          export TWPM_ZEPHYR_CMAKE_PATH=${self'.packages.zephyr-sdk}/cmake
          export PATH="${lib.makeBinPath packages}:$PATH"
        '';
      in {
        packages = {
          inherit sdk-base;
          zephyr-sdk = pkgs.callPackage ./nix/zephyr-sdk.nix {};
          riscv-toolchain-prebuilt = pkgs.callPackage ./nix/riscv-toolchain.nix {};
          west = pkgs.python311.withPackages (ps: [
            (ps.west.overridePythonAttrs (super: {
              propagatedBuildInputs = super.propagatedBuildInputs ++ [ ps.pyelftools ];
            }))
          ]);
        };
        devShells.default = pkgs.mkShellNoCC {
          shellHook = ''
            source ${sdk-base}
          '';
        };
      };
    };
}
