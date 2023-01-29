let
  pkgs = import <nixpkgs> {};
in with pkgs; {
  progs = import ./progs.nix { 
    inherit lib stdenv buildPackages fetchurl autoconf automake gettext
      libtool pkg-config icu libuuid readline inih liburcu  nixosTests;
  };
}
