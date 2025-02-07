{
  description = "Linux Kernel development environment";

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
      };

      devShells.default = lib.mkLinuxShell {
        inherit pkgs root;
        no-vm = true;
        user-config = {
          vm.disks = [5000 5000];
        };
      };

      packages = let
        src = pkgs.fetchFromGitHub {
          owner = "torvalds";
          repo = "linux";
          rev = "v6.13";
          hash = "sha256-FD22KmTFrIhED5X3rcjPTot1UOq1ir1zouEpRWZkRC0=";
        };
      in rec {
        configs = {
          xfstests = import ./xfstests/configs.nix;
        };

        kconfig = lib.buildKernelConfig {
          inherit src;
          version = "v6.13";
          kconfig = with pkgs.lib.kernel; {
            FS_VERITY = yes;
          };
        };

        kernel = lib.buildKernel {
          inherit src nixpkgs;
          version = "v6.13";
          modDirVersion = "6.13.0";
          kconfig = lib.buildKernelConfig {
            inherit src;
            version = "v6.13";
            kconfig = with pkgs.lib.kernel; {
              FS_VERITY = yes;
            };
          };
        };

        iso = lib.mkIso {
          inherit pkgs;
          user-config = {
            networking.useDHCP = pkgs.lib.mkForce true;
            boot.kernelPackages = pkgs.linuxPackagesFor kernel;
            vm.disks = [5000 5000];
          };
          test-disk = "/dev/sda";
          scratch-disk = "/dev/sdb";
        };

        vm = lib.mkVmTest {
          inherit pkgs;
          user-config = {
            networking.useDHCP = pkgs.lib.mkForce true;
            boot.kernelPackages =
              pkgs.linuxPackagesFor
              ((pkgs.linuxManualConfig
                  {
                    inherit src;
                    version = "v6.13";
                    modDirVersion = "6.13.0";
                    configfile = kconfig;
                    allowImportFromDerivation = true;
                    stdenv = pkgs.ccacheStdenv;
                  })
                .overrideAttrs (old: {
                  nativeBuildInputs = old.nativeBuildInputs ++ [pkgs.cpio];
                  stdenv = pkgs.ccacheStdenv;
                  dontStrip = true;
                  patches = [
                    ./randstruct-provide-seed.patch
                  ];
                  preConfigure = ''
                    export CCACHE_MAXSIZE=5G
                    export CCACHE_DIR=/var/cache/ccache/
                    export CCACHE_SLOPPINESS=random_seed
                    export KBUILD_BUILD_TIMESTAMP=""
                  '';
                }));
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
