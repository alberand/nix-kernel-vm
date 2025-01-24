{
  description = "VM for filesystem testing of Linux Kernel";

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
        user-config = {
          vm.disks = [5000 5000];
        };
      };

      devShells."light" = lib.mkLinuxShell {
        inherit pkgs root;
        no-vm = true;
      };

      devShells."old-kernel" =
        (lib.mkLinuxShell {
          inherit pkgs root;
          packages = [
            pkgs.gcc8
          ];
          no-vm = true;
        })
        .overrideAttrs (_final: prev: {
          nativeBuildInputs =
            nixpkgs.lib.lists.subtractLists
            [pkgs.clang pkgs.clang-tools]
            prev.nativeBuildInputs;
        });

      # Config file derivation
      packages = rec {
        default = vmtest;

        vmtest = lib.mkVmTest {
          inherit pkgs;
        };

        iso = lib.mkIso {
          inherit pkgs;
          test-disk = "/dev/sda";
          scratch-disk = "/dev/sdb";
        };

        vmtest-deploy = lib.deploy {
          inherit pkgs;
        };

        configs = {
          xfstests = import ./xfstests/configs.nix;
        };

        kernel-config = lib.buildKernelConfig {
          inherit nixpkgs pkgs;
          version = "6.11.0";
          src = pkgs.fetchgit {
            url = "git://git.kernel.org/pub/scm/fs/xfs/xfs-linux.git";
            rev = "refs/tags/xfs-6.11-fixes-4";
            hash = "sha256-xLdrvh35kHuaN0bBxOM7TURUJvPsd2yt2TcM+XoqbIk=";
          };
          structuredExtraConfig = with pkgs.lib.kernel; {
            FS_VERITY = yes;
            FS_VERITY_BUILTIN_SIGNATURES = yes;
            XFS_FS = yes;
          };
        };

        kernel = let
          version = "6.12.0-rc6";
          src = pkgs.fetchFromGitHub {
            owner = "alberand";
            repo = "linux";
            rev = "a54431da279d591c526a6a97e56ff4a2fe1dd50e";
            sha256 = "sha256-vpFsNOzwvovrQ9TdpkSHCr3IK0aNuUarmxv78o7vvbg=";
          };
        in
          lib.buildKernel {
            inherit nixpkgs src version;
            modDirVersion = version;

            configfile = lib.buildKernelConfig {
              inherit nixpkgs pkgs src version;
              structuredExtraConfig = with pkgs.lib.kernel; {
                FS_VERITY = yes;
                FS_VERITY_BUILTIN_SIGNATURES = yes;
                XFS_FS = yes;
              };
            };
          };

        kernel-latest = lib.buildKernel rec {
          inherit (pkgs.linuxPackages_latest.kernel) src version;
          inherit nixpkgs;
          modDirVersion = version;

          configfile = lib.buildKernelConfig {
            inherit nixpkgs pkgs src version;
            structuredExtraConfig = with pkgs.lib.kernel; {
              FS_VERITY = yes;
              FS_VERITY_BUILTIN_SIGNATURES = yes;
              XFS_FS = yes;
            };
          };
        };

        xfsprogs = pkgs.xfsprogs.overrideAttrs (_old: {
          src = builtins.fetchGit {
            url = "github:alberand/xfsprogs-dev";
            ref = "fsverity";
            rev = "c3bdf55a7a8051c0f9c5e79828729c92508fb0b7";
            shallow = true;
          };

          # We need to add autoconfHook because if you look into nixpkgs#xfsprogs
          # the source code fetched is not a git tree - it's tarball. The tarball is
          # actually created with 'make dist' command. This tarball already has some
          # additional stuff produced by autoconf. Here we want to take raw git tree
          # so we need to run 'make dist', but this is not the best way (why?), just
          # add autoreconfHook which will do autoconf automatically.
          nativeBuildInputs =
            pkgs.xfsprogs.nativeBuildInputs
            ++ [
              pkgs.autoreconfHook
              pkgs.attr
            ];

          # Here we need to add a few more files to the for-loop as in newer version
          # of xfsprogs there's more references to @sbindir@. No doing so will cause
          # cycle error
          # for file in scrub/{xfs_scrub_all.cron.in,xfs_scrub@.service.in,xfs_scrub_all.service.in}; do
          preConfigure = ''
            for file in scrub/{xfs_scrub_all.cron.in,xfs_scrub@.service.in,xfs_scrub_all.service.in,xfs_scrub_all.in,xfs_scrub_media@.service.in}; do
              substituteInPlace "$file" \
                --replace '@sbindir@' '/run/current-system/sw/bin'
            done
            patchShebangs ./install-sh
          '';
          postConfigure = ''
            cp include/install-sh install-sh
            patchShebangs ./install-sh
          '';
        });
      };

      apps.default = flake-utils.lib.mkApp {
        drv = packages.vmtest;
      };

      templates."xfsprogs" = {
        path = ./templates/xfsprogs;
        description = "VM for testing xfsprogs with xfstests";
        welcomeText = ''
          This is template for testing 'xfsprogs' package.

          To modify an image modify parameters in xfsprogs.nix

          To build runnable image run:

          $ nix build .#iso

          To activate development shell:

          $ nix develop .#
        '';
      };
      templates.default = self.templates."xfsprogs";

      #nixosConfigurations.xfstests-env = import ./xfstests-env.nix { inherit nixpkgs pkgs;};
    });
}
