{
  pkgs,
  version,
  src,
  configfile,
}: {
  kernel =
    pkgs.linuxPackagesFor
    (
      pkgs.callPackage pkgs.linuxManualConfig {
        inherit src configfile;
        version = "6.8.0-rc4";
        allowImportFromDerivation = true;
      }
    );
}
