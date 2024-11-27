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
  configfile,
  modDirVersion,
  version,
  enableRust ? false, # Install the Rust Analyzer
  enableGdb ? false, # Install the GDB scripts
  kernelPatches ? [],
  nixpkgs, # Nixpkgs source
}: let
  kernel =
    ((callPackage "${nixpkgs}/pkgs/os-specific/linux/kernel/manual-config.nix" {})
      {
        inherit src modDirVersion version kernelPatches lib configfile;

        allowImportFromDerivation = true;
        stdenv = ccacheStdenv;
      })
    .overrideAttrs (old: {
      nativeBuildInputs =
        old.nativeBuildInputs
        ++ lib.optionals enableRust [rustc cargo rust-bindgen];
      RUST_LIB_SRC = lib.optionalString enableRust rustPlatform.rustLibSrc;
      dontStrip = true;
      preConfigure = ''
        export CCACHE_DEBUG=1
        export CCACHE_MAXSIZE=10G
        export CCACHE_DEBUGDIR=/var/cache/ccache/ccache-debug-2
        export CCACHE_DIR=/var/cache/ccache
        export KBUILD_BUILD_TIMESTAMP=""
        export SOURCE_DATE_EPOCH=100
      '';
    });

  kernelPassthru = {
    inherit (configfile) structuredConfig;
    inherit modDirVersion configfile;
    passthru = kernel.passthru // (removeAttrs kernelPassthru ["passthru"]);
  };
in
  lib.extendDerivation true kernelPassthru kernel
