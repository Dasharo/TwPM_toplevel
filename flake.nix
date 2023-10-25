{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      pythonPackages = pkgs.python310Packages;
      pythonWithPackages = pythonPackages.python.withPackages (ps: with ps; [
        cocotb pytest
      ]);
    in
    {
      devShell = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          yosys
          nextpnr
          pythonWithPackages
          trellis ghdl
        ];
      };
    });
}
