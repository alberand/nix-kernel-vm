{
  pkgs,
  stdenv,
  ccacheStdenv,
  lib,
}: {
  src,
  kconfig,
  version,
  modDirVersion,
}:
(pkgs.linuxManualConfig
  {
    inherit src version modDirVersion lib;
    configfile = kconfig;
    allowImportFromDerivation = true;
    stdenv = ccacheStdenv;
  })
.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [pkgs.cpio];
  dontStrip = true;
  patches = [
    ./randstruct-provide-seed.patch
  ];
  preConfigure = ''
    export CCACHE_MAXSIZE=5G
    export CCACHE_DIR=/var/cache/ccache/
    export CCACHE_SLOPPINESS=random_seed
    export CCACHE_UMASK=666
    export KBUILD_BUILD_TIMESTAMP=""
  '';
})
