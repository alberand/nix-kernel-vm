{pkgs}:
pkgs.stdenv.mkDerivation {
  name = "xfstests-configs";
  version = "v1";
  src = ./.;
  installPhase = ''
    mkdir -p $out
    cp $src/*.conf $out
  '';
  passthru = {
    xfstests-all = ./xfstests-all.conf;
    xfstests-xfs-1k = ./xfstests-xfs-1k.conf;
    xfstests-xfs-4k = ./xfstests-xfs-4k.conf;
    xfstests-ext4-1k = ./xfstests-ext4-1k.conf;
    xfstests-ext4-4k = ./xfstests-ext4-4k.conf;
  };
}
