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
        export CCACHE_MAXSIZE=5G
        export CCACHE_DIR=/var/cache/ccache/
        export CCACHE_SLOPPINESS=random_seed
        export KBUILD_BUILD_TIMESTAMP=""
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
