{ self, ... }:
{
  perSystem = { self', pkgs, ... }:
  let
    pangox-compat =
    { lib, stdenv, fetchFromGitLab, autoconf, automake, libtool, pkg-config
    , pango
    , which
    , ...
    }:
    stdenv.mkDerivation {
      pname = "pangox-compat";
      version = "0.0.2";
      src = fetchFromGitLab {
        domain = "gitlab.gnome.org";
        owner = "Archive";
        repo = "pangox-compat";
        rev = "edb9e0904d04d1da02bba7b78601a2aba05aaa47";
        sha256 = "sha256-3+GaLwdxrWDFg2THa9nD880eC3E7iOzsHMGGWX9AsT4=";
      };
      nativeBuildInputs = [ which autoconf automake libtool pkg-config ];
      buildInputs = [ pango ];
      preConfigure = "./autogen.sh";
      patches = [
        ./patches/0001-Re-add-pango_x_get_shaper_map-it-is-still-used-in-th.patch
        ./patches/0002-disable-shaper.patch
      ];
    };
    libtiff_3 = { lib, stdenv, fetchurl, ... }:
    stdenv.mkDerivation rec {
      pname = "libtiff";
      version = "3.9.7";
      src = fetchurl {
        urls = [
          "ftp://ftp.remotesensing.org/pub/libtiff/tiff-${version}.tar.gz"
          "http://download.osgeo.org/libtiff/tiff-${version}.tar.gz"
        ];
        sha256 = "0spg1hr5rsrmg88sfzb05qnf0haspq7r5hvdkxg5zib1rva4vmpm";
      };
    };
    diamond =
    { lib, stdenv, fetchurl, rpmextract, patchelf, makeWrapper
    , glibc, glib, zlib, libxml2, sqlite, graphite2, libuuid, libkrb5
    , freetype, fontconfig, libglvnd, gst_all_1, xorg
    , libusb-compat-0_1, expat, bzip2, gdk-pixbuf, gtk2-x11, pango, atk
    , ...
    }:
    stdenv.mkDerivation rec {
      pname = "diamond";
      version = "3.13";

      src = fetchurl {
        url = "https://files.latticesemi.com/Diamond/3.13/diamond_3_13-base-56-2-x86_64-linux.rpm";
        sha256 = "1li9yvgd3zamijb8l7jaq663qxn5vamr95y1b5ig342nxvd8g9yg";
      };

      nativeBuildInputs = [ rpmextract patchelf makeWrapper ];
      outputs = [ "out" "unwrapped" ];

      unpackPhase = ''
        mkdir $unwrapped
        cd $unwrapped
        rpmextract $src
        mv usr/local/diamond/${version} diamond
        rm -rf usr

        cd $unwrapped/diamond/bin
        tar xf bin.tar.gz && rm bin.tar.gz

        cd $unwrapped/diamond/cae_library
        tar xf cae_library.tar.gz && rm cae_library.tar.gz

        cd $unwrapped/diamond/data
        tar xf data.tar.gz && rm data.tar.gz

        cd $unwrapped/diamond/embedded_source
        tar xf embedded_source.tar.gz && rm embedded_source.tar.gz

        cd $unwrapped/diamond/examples
        tar xf examples.tar.gz && rm examples.tar.gz

        cd $unwrapped/diamond/ispfpga
        tar xf ispfpga.tar.gz && rm ispfpga.tar.gz

        cd $unwrapped/diamond/modeltech
        tar xf modeltech.tar.gz && rm modeltech.tar.gz

        cd $unwrapped/diamond/synpbase
        tar xf synpbase.tar.gz && rm synpbase.tar.gz

        cd $unwrapped/diamond/tcltk
        tar xf tcltk.tar.gz && rm tcltk.tar.gz
      '';

      installPhase = ''
        mkdir $out
        cd $out

        mkdir bin
        for file in {diamond,diamondc}; do
          makeWrapper "$unwrapped/diamond/bin/lin64/$file" "$out/bin/$file" \
                --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
                  glibc glib zlib libxml2 sqlite graphite2 libuuid libkrb5
                  xorg.libX11 xorg.libSM xorg.libICE xorg.libXext xorg.libXrender xorg.libXau
                  xorg.libXt xorg.libXcomposite xorg.libXi xorg.libXinerama xorg.libXxf86vm
                  xorg.libXft xorg.libXScrnSaver xorg.libxcb
                  freetype fontconfig.lib libglvnd gst_all_1.gstreamer gst_all_1.gst-plugins-base
                  libusb-compat-0_1 expat bzip2 gdk-pixbuf gtk2-x11 pango atk self'.packages.pangox-compat
                  self'.packages.libtiff_3
                ]}"
        done
      '';

      postFixup = ''
        for file in $(find $unwrapped); do
          if file $file | grep -qE 'ELF.*executable.*interpreter'; then
            patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              $file
          fi
        done
      '';
    };
  in rec {
    packages.pangox-compat = pkgs.callPackage pangox-compat {};
    packages.libtiff_3 = pkgs.callPackage libtiff_3 {};
    packages.diamond = pkgs.callPackage diamond {};
    apps.diamondc = { type = "app"; program = "${packages.diamond.out}/bin/diamondc"; };
  };
}
