{ pkgs ? import <nixpkgs> {}/*, drives */ }:
pkgs.stdenv.mkDerivation rec {
  coreutils = pkgs.coreutils;
  /*drives = drives;*/
  name = "fstest-config-${version}";
  version = "1.0";
  builder = "${pkgs.bash}/bin/bash";
  args = [ ./builder.sh ];
}
