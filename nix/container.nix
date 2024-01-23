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

      if [ -d /etc/twpm ]; then
        for f in /etc/twpm/*; do
          source $f
        done
      fi
      exec bash -i
    '';
    buildSdk = name: layers: nix2container.buildImage {
      inherit name;
      layers = [ sdkBaseLayer ] ++ layers;
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
    sdkBaseLayer = nix2container.buildLayer {
      deps = containerBasePackages;
    };
    mkLayer = { name, deps, addToPath ? true, order ? 99, overlays ? [] }:
    nix2container.buildLayer {
      inherit deps;
      copyToRoot =
      let
        overlay = pkgs.writeTextFile {
          name = "${name}-env-init";
          text = ''
            export PATH="${lib.makeBinPath deps}:$PATH"
          '';
          destination = "/etc/twpm/${builtins.toString order}-${name}";
        };
      in [ overlay ] ++ overlays;
    };
    diamondLayer = mkLayer {
      name = "diamond";
      deps = [ self'.packages.diamond ];
      overlays = [
        (pkgs.runCommand "link-id" {} ''
          mkdir -p $out/usr/bin
          cd $out/usr/bin
          ln -s ${pkgs.coreutils}/bin/id .

          cd ../..
          mkdir etc
          cd etc
          for i in {0..2000}; do
            echo builder$i:x:$i:$i:Builder $i:/var/empty:/sbin/nologin >> passwd
          done
        '')
      ];
    };
    litexLayer = mkLayer {
      name = "litex";
      deps = [ self'.packages.litex ];
    };
  in {
    packages.sdk = buildSdk "twpm-sdk" [];
    packages.sdk-litex = buildSdk "twpm-sdk-litex" [ litexLayer ];
    packages.sdk-diamond = buildSdk "twpm-sdk-diamond" [ diamondLayer ];
    packages.sdk-full = buildSdk "twpm-sdk-full" [ litexLayer diamondLayer ];
  };
}
