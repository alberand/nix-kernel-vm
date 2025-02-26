{
  description = "Linux Kernel development environment";

  nixConfig = {
    # override the default substituters
    substituters = [
      "http://192.168.0.100"
    ];

    trusted-public-keys = [
      "192.168.0.100:T4If+3X03bZC62Jh+Uzuz+ElERtgQFlbarUQE1PzC94="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nixos-generators,
  }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
      # default kernel if no custom kernel were specified
      root = builtins.toString ./.;
    in rec {
      lib = import ./lib.nix {
        inherit pkgs nixos-generators nixpkgs;
        inherit (packages) xfstests-configs;
      };

      devShells.default =
        (lib.mkLinuxShell {
          inherit pkgs root;
        })
        .overrideAttrs (_final: prev: {
          shellHook =
            prev.shellHook
            + ''
              echo "$(tput setaf 214)Welcome to kernel dev-shell.$(tput sgr0)"
            '';
        });

      packages = let
        src = pkgs.fetchFromGitHub {
          owner = "torvalds";
          repo = "linux";
          rev = "v6.13";
          hash = "sha256-FD22KmTFrIhED5X3rcjPTot1UOq1ir1zouEpRWZkRC0=";
        };
        kernel-config = lib.buildKernelConfig {
          inherit src;
          version = "v6.13";
          kconfig = with pkgs.lib.kernel; {
            FS_VERITY = yes;
          };
        };
      in rec {
        xfstests-configs = pkgs.stdenv.mkDerivation {
          name = "xfstests-configs";
          version = "v1";
          src = ./xfstests;
          installPhase = ''
            mkdir -p $out
            cp $src/*.conf $out
          '';
          passthru = {
            xfstests-all = ./xfstests/xfstests-all.conf;
            xfstests-xfs-1k = ./xfstests/xfstests-xfs-1k.conf;
            xfstests-xfs-4k = ./xfstests/xfstests-xfs-4k.conf;
            xfstests-ext4-1k = ./xfstests/xfstests-ext4-1k.conf;
            xfstests-ext4-4k = ./xfstests/xfstests-ext4-4k.conf;
          };
        };

        kconfig = kernel-config;
        kconfig-iso = lib.buildKernelConfig {
          inherit src;
          version = "v6.13";
          iso = true;
          kconfig = with pkgs.lib.kernel; {
            FS_VERITY = yes;
          };
        };

        kernel = lib.buildKernel {
          inherit src nixpkgs kconfig;
          version = "v6.13";
          modDirVersion = "6.13.0";
        };

        iso = lib.mkIso {
          inherit pkgs;
          user-config = {
            networking.useDHCP = pkgs.lib.mkForce true;
            boot.kernelPackages = pkgs.linuxPackagesFor (
              lib.buildKernel {
                inherit src;
                version = "v6.13";
                modDirVersion = "6.13.0";
                kconfig = kconfig-iso;
              }
            );

            programs.xfstests = {
              enable = true;
              src = pkgs.fetchgit {
                url = "git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git";
                rev = "v2024.12.22";
                sha256 = "sha256-xZkCZVvlcnqsUnGGxSFqOHoC73M9ijM5sQnnRqamOk8=";
              };
              testconfig = packages.xfstests-configs.xfstests-all;
              test-dev = "/dev/sda";
              scratch-dev = "/dev/sdb";
              arguments = "-R xunit -s xfs_4k generic/110";
              upload-results = true;
            };
          };
        };

        vm = lib.mkVmTest {
          inherit pkgs;
          user-config = {
            networking.useDHCP = pkgs.lib.mkForce true;
            boot.kernelPackages = pkgs.linuxPackagesFor (
              lib.buildKernel {
                inherit src kconfig;
                version = "v6.13";
                modDirVersion = "6.13.0";
              }
            );
            vm.disks = [5000 5000];
          };
        };

        vmtest = {
          inherit vm iso kconfig kernel;
        };
      };

      apps.default = flake-utils.lib.mkApp {
        drv = packages.vmtest;
      };

      templates."kernel-dev" = {
        path = ./templates/kernel-dev;
        description = "Development shell for Linux kernel with image builder";
        welcomeText = ''
          This is template for testing 'xfsprogs'/'xfstests' package.

          To modify an image modify parameters in xfsprogs.nix

          To build runnable image run:

          $ nix build .#iso

          To activate development shell:

          $ nix develop .#xfsprogs
          $ nix develop .#xfstests
        '';
      };
      templates.default = self.templates."kernel-dev";
    });
}
