{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    fetch-lore.url = "github:dramforever/fetch-lore";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, fetch-lore, nixos-generators }:
  flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
  let
    pkgs = import nixpkgs {
      inherit system;
    };
    # default kernel if no custom kernel were specified
    root = builtins.toString ./.;
  in rec {
    lib = import ./lib.nix {
      inherit pkgs nixos-generators;
    };

    devShells.default = lib.mkLinuxShell {
      inherit pkgs root;
      qemu-options = [
        "-hda /dev/loop0"
        "-hdb /dev/loop1"
      ];
    };

    packages = rec {
      default = vmtest;

      vmtest = lib.mkVmTest {
        inherit pkgs;
        qemu-options = [
          "-hda /dev/loop0"
          "-hdb /dev/loop1"
        ];
      };

      iso = lib.mkIso {
        inherit pkgs;
      };

      deploy = lib.deploy {
        inherit pkgs;
      };
    };

    apps.default = flake-utils.lib.mkApp {
      drv = packages.vmtest;
    };
  });
}
