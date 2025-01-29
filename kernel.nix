{
  pkgs,
  stdenv,
  ccacheStdenv,
  lib,
  callPackage,
  rustc,
  cargo,
  rust-bindgen,
  buildPackages,
  rustPlatform,
}: {
  src,
  kconfig,
  version,
  modDirVersion,
  nixpkgs,
  kernelPatches ? [],
}: let
  kernel =
    ((callPackage "${nixpkgs}/pkgs/os-specific/linux/kernel/manual-config.nix" {})
      {
        inherit src version modDirVersion lib;
        configfile = kconfig;

        extraMakeFlags = ["SOURCE_DATE_EPOCH=0"];
        allowImportFromDerivation = true;
        stdenv = ccacheStdenv;
      })
    .overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [pkgs.cpio];
      dontStrip = true;
        patches =
          [
              ./randstruct-provide-seed.patch
          ];
      preConfigure = ''
        export CCACHE_DEBUG=1
        export CCACHE_MAXSIZE=10G
        export CCACHE_DEBUGDIR=/var/cache/ccache/ccache-debug-5
        export CCACHE_DIR=/var/cache/ccache/
        export CCACHE_SLOPPINESS=random_seed
        export KBUILD_BUILD_TIMESTAMP=""
        export SOURCE_DATE_EPOCH=0
      '';
    });

  kernelPassthru = {
    inherit (kconfig) structuredConfig;
    inherit modDirVersion;
    configfile = kconfig;
    passthru = kernel.passthru // (removeAttrs kernelPassthru ["passthru"]);
  };
in
  lib.extendDerivation true kernelPassthru kernel
