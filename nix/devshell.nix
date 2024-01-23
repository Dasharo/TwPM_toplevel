{ self, ... }:
{
  perSystem = { self', pkgs, ... }:
  let
    inherit (pkgs) lib;
  in rec {
    devShells = {
      default = pkgs.mkShellNoCC {
        shellHook = ''
          source ${self'.packages.sdk-base}
        '';
      };
      with-litex = pkgs.mkShellNoCC {
        shellHook = ''
          source ${self'.packages.sdk-base}
          export PATH="${lib.makeBinPath [ self'.packages.litex ]}:$PATH"
        '';
      };
      with-diamond = pkgs.mkShellNoCC {
        shellHook = ''
          source ${self'.packages.sdk-base}
          export PATH="${lib.makeBinPath [ self'.packages.diamond ]}:$PATH"
        '';
      };
      full = pkgs.mkShellNoCC {
        shellHook = ''
          source ${self'.packages.sdk-base}
          export PATH="${lib.makeBinPath [ self'.packages.litex self'.packages.diamond ]}:$PATH"
        '';
      };
    };
  };
}
