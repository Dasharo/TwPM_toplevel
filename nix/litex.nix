{ self, inputs, ... }:
{
  perSystem = { self', inputs', pkgs, system, ... }:
  let
    # Use Python 3.10, Litex does not work properly with newer Python.
    pythonPackages = pkgs.python310Packages;

    buildPackage = { pname, version, src, ... }@attrs: pythonPackages.buildPythonPackage ({
      inherit pname version src;
      doCheck = false;
    } // attrs);
    buildPackageFromFlakeInput = pname: attrs: buildPackage ({
      inherit pname;
      version = inputs.${pname}.shortRev;
      src = inputs.${pname};
    } // attrs);
    migen = buildPackageFromFlakeInput "migen" {
      propagatedBuildInputs = with pythonPackages; [ colorama ];
    };
    litex = buildPackageFromFlakeInput "litex" {
      postPatch = ''
        substituteInPlace litex/soc/software/common.mak \
          --replace "PYTHON ?= python3" "PYTHON ?= \$(NIX_LITEX_PYTHON_PATH)"
      '';
      propagatedBuildInputs = with pythonPackages; [
        migen
        packaging
        pyserial
        requests
      ];
    };
    litedram = buildPackageFromFlakeInput "litedram" {
      propagatedBuildInputs = with pythonPackages; [ litex pyyaml ];
    };
    litex-boards = buildPackageFromFlakeInput "litex-boards" {
      propagatedBuildInputs = [ litex ];
    };
  in
  {
    packages = rec {
      litex = pythonPackages.python.withPackages (ps: [
        litex litedram
      ]);
    };
    apps =
    let
      litexapp = app: { type = "app"; program = "${self'.packages.litex}/bin/${app}"; };
    in {
      litedram_gen = litexapp "litedram_gen";
      litex_bare_metal_demo = litexapp "litex_bare_metal_demo";
      litex_cli = litexapp "litex_cli";
      litex_contributors = litexapp "litex_contributors";
      litex_json2dts_linux = litexapp "litex_json2dts_linux";
      litex_json2dts_zephyr = litexapp "litex_json2dts_zephyr";
      litex_json2renode = litexapp "litex_json2renode";
      litex_periph_gen = litexapp "litex_periph_gen";
      litex_read_verilog = litexapp "litex_read_verilog";
      litex_server = litexapp "litex_server";
      litex_sim = litexapp "litex_sim";
      litex_soc_gen = litexapp "litex_soc_gen";
      litex_term = litexapp "litex_term";
    };
  };
}
