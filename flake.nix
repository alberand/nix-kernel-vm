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

      packages = {
        configs = {
          xfstests = import ./xfstests/configs.nix;
        };

        kconfig = lib.buildKernelConfig {
          src = pkgs.fetchFromGitHub {
            owner = "alberand";
            repo = "linux";
            rev = "testing-ccache";
            hash = "sha256-ATTckJxW+/qD8hjpHDm0HTfIMyR41Qgd65ndNvsxsa4=";
          };
          version = "xfs-xattrat";
          kconfig = with pkgs.lib.kernel; {
            FS_VERITY = yes;
          };
        };

        kernel = let
          src = pkgs.fetchFromGitHub {
            owner = "alberand";
            repo = "linux";
            rev = "testing-ccache";
            hash = "sha256-10Xm3ZInyjRB2CrRyTilFOFpeTwJz2+k/PvwmN90fOo=";
          };
        in
          lib.buildKernel {
            inherit src nixpkgs;
            version = "testing-ccache";
            modDirVersion = "6.13.0-rc4";
            kconfig = lib.buildKernelConfig {
              inherit src;
              version = "testing-ccache";
              kconfig = with pkgs.lib.kernel; {
                FS_VERITY = yes;
              };
            };
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
