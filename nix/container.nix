{ self, ... }:
{
  perSystem = { self', inputs', pkgs, system, ... }:
  let
    inherit (inputs'.nix2container.packages) nix2container;
    inherit (pkgs) lib writeShellScript;

    containerBasePackages = with pkgs; [
      bashInteractive
      coreutils
      findutils
      gnugrep
      gnused
      gcc
    ];
    containerInit = writeShellScript "twpm-container-init" ''
      export PATH="${lib.makeBinPath containerBasePackages}"

      mkdir /tmp &>/dev/null || true

      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      source ${self'.packages.sdk-base}
      exec bash -i
    '';
  in {
    packages.sdk = nix2container.buildImage {
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
}
