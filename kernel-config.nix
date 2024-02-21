{
  stdenv,
  lib,
  perl,
  gmp,
  libmpc,
  mpfr,
  bison,
  flex,
  pahole,
  buildPackages,
  rustPlatform,
  rustc,
  rustfmt,
  cargo,
  rust-bindgen,
}: {
  pkgs,
  nixpkgs,
  structuredExtraConfig,
  kernel ? pkgs.linuxPackages_latest.kernel,
  withRust ? false,
  enableCommonConfig ? false,
  commonStructuredConfig ? [],
  structuredConfigFromPatches ? [],
  defconfig ? null,
}:
stdenv.mkDerivation
rec {
  kernelArch = stdenv.hostPlatform.linuxArch;
  extraMakeFlags = [];

  inherit (kernel) src patches version;
  pname = "linux-config";

  RUST_LIB_SRC = lib.optionalString withRust rustPlatform.rustLibSrc;

  # Flags that get passed to generate-config.pl
  # ignoreConfigErrors: Ignores any config errors in script (eg unused options)
  # autoModules: Build every available module
  # preferBuiltin: Build modules as builtin
  inherit (stdenv.hostPlatform.linux-kernel) autoModules;
  preferBuiltin = false; # or false
  ignoreConfigErrors = true;
  generateConfig = "${nixpkgs}/pkgs/os-specific/linux/kernel/generate-config.pl";

  kernelConfig = passthru.moduleStructuredConfig.intermediateNixConfig;
  passAsFile = ["kernelConfig"];

  depsBuildBuild = [buildPackages.stdenv.cc];
  nativeBuildInputs =
    [perl gmp libmpc mpfr bison flex bison flex pahole]
    ++ lib.optionals withRust [rust-bindgen rustc rustfmt cargo];

  platformName = stdenv.hostPlatform.linux-kernel.name;
  # e.g. "bzImage"
  kernelTarget = stdenv.hostPlatform.linux-kernel.target;
  kernelBaseConfig =
    if defconfig != null
    then defconfig
    else stdenv.hostPlatform.linux-kernel.baseConfig;

  makeFlags =
    lib.optionals (stdenv.hostPlatform.linux-kernel ? makeFlags)
    stdenv.hostPlatform.linux-kernel.makeFlags;

  postPatch =
    kernel.postPatch
    + ''
      # Patch kconfig to print "###" after every question so that
      # generate-config.pl from the generic builder can answer them.
      sed -e '/fflush(stdout);/i\printf("###");' -i scripts/kconfig/conf.c
    '';

  preUnpack = kernel.preUnpack or "";

  buildPhase = ''
    export buildRoot="''${buildRoot:-build}"
    export HOSTCC=$CC_FOR_BUILD
    export HOSTCXX=$CXX_FOR_BUILD
    export HOSTAR=$AR_FOR_BUILD
    export HOSTLD=$LD_FOR_BUILD

    # Get a basic config file for later refinement with $generateConfig.
    make $makeFlags \
        -C . O="$buildRoot" $kernelBaseConfig \
        ARCH=$kernelArch \
        HOSTCC=$HOSTCC HOSTCXX=$HOSTCXX HOSTAR=$HOSTAR HOSTLD=$HOSTLD \
        CC=$CC OBJCOPY=$OBJCOPY OBJDUMP=$OBJDUMP READELF=$READELF \
        $makeFlags

    # Create the config file.
    echo "generating kernel configuration..."
    ln -s "$kernelConfigPath" "$buildRoot/kernel-config"
    DEBUG=1 ARCH=$kernelArch KERNEL_CONFIG="$buildRoot/kernel-config" AUTO_MODULES=$autoModules \
      PREFER_BUILTIN=$preferBuiltin BUILD_ROOT="$buildRoot" SRC=. MAKE_FLAGS="$makeFlags" \
      perl -w $generateConfig
  '';

  installPhase = "mv $buildRoot/.config $out";

  enableParallelBuilding = true;

  passthru = rec {
    module = import "${nixpkgs}/nixos/modules/system/boot/kernel_config.nix";
    # used also in apache
    # { modules = [ { options = res.options; config = svc.config or svc; } ];
    #   check = false;
    # The result is a set of two attributes
    moduleStructuredConfig =
      (lib.evalModules {
        modules =
          [
            module
          ]
          ++ lib.optionals enableCommonConfig [
            {
              settings = commonStructuredConfig;
              _file = "pkgs/os-specific/linux/kernel/common-config.nix";
            }
          ]
          ++ [
            {
              settings = structuredExtraConfig;
              _file = "structuredExtraConfig";
            }
          ]
          ++ structuredConfigFromPatches;
      })
      .config;

    structuredConfig = moduleStructuredConfig.settings;
  };
}
