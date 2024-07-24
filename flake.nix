{
  description = "Unfucking the Zephyr/Nrf Experience";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    zephyr-sdk = {
      url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.8/zephyr-sdk-0.16.8_linux-x86_64.tar.xz";
      flake = false;
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        flake-parts.flakeModules.easyOverlay
      ];
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        _module.args.pkgs = import inputs.nixpkgs { inherit system; overlays = [ inputs.self.overlays.default ]; config = { allowUnfree = true; segger-jlink.acceptLicense = true; }; };
        overlayAttrs = config.packages // config.legacyPackages;
        legacyPackages = {
          fetchWestWorkspace = pkgs.callPackage ./functions/fetchWestWorkspace { };
          mkZephyrProject = pkgs.callPackage ./functions/mkZephyrProject { };
        };
        packages = {
          zephyr-sdk = pkgs.stdenv.mkDerivation {
            name = "zephyr-sdk-patched";
            nativeBuildInputs = with pkgs; [ autoPatchelfHook ];
            buildInputs = with pkgs; [ pkgs.stdenv.cc.cc.lib python38 ];
            installPhase = "ls -lah";
            src = inputs.zephyr-sdk;
            buildPhase = ''
              cp -r $src $out
            '';
          };
          # It's not entirely clear based on the documentation which of all of these
          # dependencies are actually necessary to build Zephyr, the list may increase
          # depending on the ongoing changes upstream
          zephyrPython = pkgs.python39.withPackages (p: with p; [
            docutils
            wheel
            breathe
            sphinx
            sphinx_rtd_theme
            ply
            pyelftools
            pyserial
            pykwalify
            colorama
            pillow
            intelhex
            pytest
            gcovr
            tkinter
            future
            cryptography
            setuptools
            pyparsing
            click
            kconfiglib
            pylink-square
            pyyaml
            cbor2
            west
            ecdsa
            anytree
          ]);
        };
        devShells.default =
          let
            westWorkspace = pkgs.fetchWestWorkspace {
              url = "https://github.com/nrfconnect/sdk-nrf";
              rev = "v2.7.0";
              sha256 = "sha256-hgSCnMACMY0dq6LhtyBBvl4ZSeKa21RVwzIoaytpjxE=";
            };
          in pkgs.mkShell {
            shellHook = ''
#            export GNUARMEMB_TOOLCHAIN_PATH=$#{pkgs.gcc-arm-embedded-11}

            export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
            export ZEPHYR_SDK_INSTALL_DIR=${pkgs.zephyr-sdk};
            export PATH=${pkgs.zephyr-sdk}/arm-zephyr-eabi/bin:$PATH
            export PYTHONPATH=${pkgs.zephyrPython}/lib/python3.10/site-packages:$PYTHONPATH
          '';
          buildInputs = with pkgs;
          let
          in [
              nrfconnect
              nrf-command-line-tools
              dtc
              gn
              gperf
              ninja
              cmake
              zephyrPython
          ];
        };
      };
      flake = {
      };
    };
}


