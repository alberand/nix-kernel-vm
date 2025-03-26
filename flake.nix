{
  description = "kd - Linux Kernel development toolset";

  nixConfig = {
    # override the default substituters
    # TODO this need to be replaced with public bucket or something
    extra-substituters = [
      "http://192.168.0.100"
    ];

    extra-trusted-public-keys = [
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
        overlays = [
          (final: prev: {
            xfstests-configs = (import ./xfstests/configs.nix) {pkgs = prev;};
          })
        ];
      };
      # default kernel if no custom kernel were specified
      root = builtins.toString ./.;
    in rec {
      lib = import ./lib.nix {
        inherit pkgs nixos-generators nixpkgs;
      };

      devShells.default =
        (lib.mkLinuxShell {
          inherit pkgs root;
        })
        .overrideAttrs (_final: prev: {
          shellHook =
            prev.shellHook
            + ''
              echo "$(tput setaf 166)Welcome to $(tput setaf 227)kd$(tput setaf 166) shell.$(tput sgr0)"
            '';
        });

      packages = let
        src = pkgs.fetchFromGitHub {
          owner = "torvalds";
          repo = "linux";
          rev = "v6.13";
          hash = "sha256-FD22KmTFrIhED5X3rcjPTot1UOq1ir1zouEpRWZkRC0=";
        };
      in rec {
        kconfig = lib.buildKernelConfig {
          inherit src;
          version = "v6.13";
        };

        kconfig-iso = lib.buildKernelConfig {
          inherit src;
          version = "v6.13";
          iso = true;
        };

        headers = lib.buildKernelHeaders {
          inherit src;
          version = "v6.13";
        };

        kernel = lib.buildKernel {
          inherit src kconfig;
          version = "v6.13";
          modDirVersion = "6.13.0";
        };

        iso = lib.mkIso {
          inherit pkgs;
          user-config = {
            kernel = {
              inherit src;
              version = "v6.13";
              modDirVersion = "6.13.0";
              kconfig = kconfig-iso;
            };

            programs.xfstests = {
              enable = true;
              src = pkgs.fetchgit {
                url = "git://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git";
                rev = "v2024.12.22";
                sha256 = "sha256-xZkCZVvlcnqsUnGGxSFqOHoC73M9ijM5sQnnRqamOk8=";
              };
              testconfig = pkgs.xfstests-configs.xfstests-all;
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
            kernel = {
              src = src;
              kconfig = kconfig;
              version = "v6.13";
              modDirVersion = "6.13.0";
            };
            vm.disks = [5000 5000];
          };
        };

        kd = {
          inherit vm iso kconfig kernel;
        };
      };

      apps.default = flake-utils.lib.mkApp {
        drv = packages.kd;
      };

      templates.vm = {
        path = ./templates/vm;
        description = "Development shell for Linux kernel with image builder";
        welcomeText = ''
          This is template for testing Linux kernel with xfstests.
        '';
      };
      templates.default = self.templates.vm;
    });
}
