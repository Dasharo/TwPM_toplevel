{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    migen.url = "github:m-labs/migen/0.9.2";
    migen.flake = false;
    litex.url = "github:enjoy-digital/litex/2023.08";
    litex.flake = false;
    litex-boards.url = "github:litex-hub/litex-boards";
    litex-boards.flake = false;
    litedram.url = "github:enjoy-digital/litedram/2023.08";
    litedram.flake = false;
    valentyusb.url = "github:litex-hub/valentyusb/hw_cdc_eptri";
    valentyusb.flake = false;
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
    pythondata-cpu-vexriscv = {
      url = "https://github.com/litex-hub/pythondata-cpu-vexriscv";
      flake = false;
      type = "git";
      submodules = true;
    };
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./nix/container.nix
        ./nix/litex.nix
        ./nix/diamond.nix
        ./nix/devshell.nix
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
      };
    };
}
