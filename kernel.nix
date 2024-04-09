{
  stdenv,
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
      })
    .overrideAttrs (old: {
      nativeBuildInputs =
        old.nativeBuildInputs
        ++ lib.optionals enableRust [rustc cargo rust-bindgen];
      RUST_LIB_SRC = lib.optionalString enableRust rustPlatform.rustLibSrc;
      dontStrip = true;
    });

  kernelPassthru = {
    inherit (configfile) structuredConfig;
    inherit modDirVersion configfile;
    passthru = kernel.passthru // (removeAttrs kernelPassthru ["passthru"]);
  };
in
  lib.extendDerivation true kernelPassthru kernel
