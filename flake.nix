{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    fetch-lore.url = "github:dramforever/fetch-lore";
    nixos-generators.url = "github:nix-community/nixos-generators";
    kernel-config.url = "/home/alberand/Projects/xfs-verity-v3/.config";
    kernel-config.flake = false;
    xfstests-config.url = "/home/alberand/Projects/nix-kernel-vm/xfstests.config";
    xfstests-config.flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, fetch-lore, nixos-generators,
      kernel-config, xfstests-config, pkgs }:
  flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
  let
    pkgs = import nixpkgs {
      inherit system;
    };
    # default kernel if no custom kernel were specified
    root = builtins.toString ./.;
    modules = [
      ({config, pkgs, ...}: {
        programs.xfstests = {
          enable = true;
          sharedir = "/root/vmtest";
          src = pkgs.fetchFromGitHub {
            owner = "alberand";
            repo = "xfstests";
            rev = "068d7af36369c7c3da7d165c50b378e7b7ce46fd";
            sha256 = "sha256-okVvdUG7ixDm7awquBvLQmN4qGma4DFM8vSJ/4VJoL0=";
          };
          testconfig = xfstests-config;
          arguments = "-s xfs_4k generic/110";
        };

        # Let's also include specific version of xfsprogs
        nixpkgs.overlays = [
          (self: super: {
            xfsprogs = super.xfsprogs.overrideAttrs ({
              version = "git";
              src = pkgs.fetchFromGitHub {
                owner = "alberand";
                repo = "xfsprogs";
                rev = "ee2abc6b88dcd1b2d826904701f0b57e59d887bf";
                sha256 = "sha256-RdDgUU81FpPNDi3S5uc8NdOQGig4s1mKH0eRF4sGUOQ=";
              };
            });
          })
        ];

        boot.kernelPackages = (pkgs.linuxPackagesFor (pkgs.callPackage pkgs.linuxManualConfig {
          inherit (pkgs) stdenv;
          version = "6.5.0-rc4";
          allowImportFromDerivation = true;
          src = pkgs.fetchFromGitHub {
            owner = "alberand";
            repo = "linux";
            rev = "3edb86cbccfa4ff683dc217689e537ea1b0225ad";
            sha256 = "sha256-N3B0Cc/EPAV+PpNC+69hN9P5XguPI6VaXoWmHh9eloE=";
          };
          configfile = kernel-config;
        }));
      })
    ];
  in rec {
    lib = import ./lib.nix {
      inherit pkgs nixos-generators;
    };

    devShells.default = lib.mkLinuxShell {
      inherit pkgs root;
      sharedir = "/tmp/vmtest";
      qemu-options = [
        "-hdb /dev/sda4"
        "-hdc /dev/sda5"
      ];
      user-modules = modules;
      packages = [
        packages.deploy
      ];
    };

    packages = rec {
      default = vmtest;

      vmtest = lib.mkVmTest {
        inherit pkgs;
        sharedir = "/tmp/vmtest";
        qemu-options = [
          "-hdb /dev/sda4"
          "-hdc /dev/sda5"
        ];
        user-modules = modules;
      };

      iso = lib.mkIso {
        inherit pkgs;
        user-modules = modules;
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
