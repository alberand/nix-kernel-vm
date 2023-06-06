{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, pkgs }:
  flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = import nixpkgs { inherit system; };
    # default kernel if no custom kernel were specified
    kernel-default = pkgs.linuxPackages_6_1;
  in rec {
    lib = {
      mkSys = {
        pkgs,
        kernel-custom ? kernel-default,
        xfstests,
        xfsprogs
      }: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./vm.nix

          ({ config, pkgs, ... }: {
            programs.xfstests = {
              enable = true;
              src = xfstests;
            };

            boot.kernelPackages = kernel-custom;

            nixpkgs.overlays = [
              (self: super: {
                xfsprogs = super.xfsprogs.overrideAttrs (prev: {
                  version = "git";
                  src = xfsprogs;
                });
              })
            ];
          })

        ];
      };

      mkVmTest = {
        pkgs,
        kernel-custom ? kernel-default,
        xfstests,
        xfsprogs
      }:
      builtins.getAttr "vmtest" rec {
        #pkgs = import nixpkgs { inherit system; };
        nixos = lib.mkSys {
          inherit pkgs xfstests xfsprogs kernel-custom;
        };

        vm-system = pkgs.symlinkJoin {
          name = "vm-system";
          paths = with nixos.config.system.build; [
            vm
            kernel
          ];
          preferLocalBuild = true;
        };

        vmtest = pkgs.writeScriptBin "vmtest"
        ((builtins.readFile ./run.sh) + ''
            ${vm-system}/bin/run-vm-vm
            echo "View results at $SHARE_DIR/results"
        '');
      };

      mkLinuxShell = {
        pkgs,
        root,
        kernel-custom ? kernel-default,
        xfstests,
        xfsprogs
      }:
      builtins.getAttr "shell" rec {
        nixos = lib.mkSys {
          inherit xfstests xfsprogs;
        };

        vm-system = pkgs.symlinkJoin {
          name = "vm-system";
          paths = with nixos.config.system.build; [
            vm
            kernel
          ];
          preferLocalBuild = true;
        };

        vmtest = pkgs.writeScriptBin "vmtest"
        ((builtins.readFile ./run.sh) + ''
            ${vm-system}/bin/run-vm-vm
            echo "View results at $SHARE_DIR/results"
        '');

        shell = pkgs.mkShell {
          packages = with pkgs; [
            (lib.mkVmTest {
              inherit pkgs xfstests xfsprogs kernel-custom;
            })
          ];

          nativeBuildInputs = with pkgs; [
            ctags
            getopt
            flex
            bison
            perl
            gnumake
            bc
            pkg-config
            clang
            clang-tools
            file
            gettext
            libtool
            qemu_full
            qemu-utils
            automake
            autoconf
            e2fsprogs
            attr
            acl
            libaio
            keyutils
            fsverity-utils
            ima-evm-utils
            util-linux
            stress-ng
            dbench
            pkgs.xfsprogs
            fio
            linuxquota
            nvme-cli
          ];

          buildInputs = with pkgs; [
            elfutils
            ncurses
            openssl
            zlib
          ];

          shellHook = ''
            if [ ! -f ${root}/compile_commands.json ]; then
              ${root}/scripts/clang-tools/gen_compile_commands.py
            fi
          '';

        };
      };
    };

    pkgs.vmtest = let
      pkgs = import nixpkgs { inherit system; };
    in lib.mkVmTest {
      inherit pkgs;
      xfstests = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfstests";
        rev = "f64ffc3dc27e155f80c9d42629d9131106d8e404";
        sha256 = "sha256-qinniYrWmw1kKuvhrt32Kp1oZCIG/tyyqNKISU5ui90=";
      };

      kernel-custom = let
        linux-custom = { fetchurl, buildLinux, ... } @ args:
        buildLinux (args // rec {
          version = "6.4.0-rc3";
          modDirVersion = version;

          src = fetchurl {
            url = "https://git.kernel.org/torvalds/t/linux-6.4-rc3.tar.gz";
            sha256 = "sha256-xlN7KcrtykVG3W9DDbODKNKJehGCAQOr4R2uw3hfxoE=";
            #url = "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.19.283.tar.xz";
            #sha256 = "sha256-BHMW0gxsl61BxAR3x+GrC+pDQkPhe/xyFVgBsSPMUfQ=";
          };
          kernelPatches = [
            {
              name = "revert-ext4-refactor";
              patch = /home/alberand/Projects/linux/patches/0001-ext4-need-rw-access-to-load-and-init-journal.patch;
            }
          ];

          extraConfig = ''
          '';
        } // (args.argsOverride or {}));
        kernel = pkgs.callPackage linux-custom {};
      in
        pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor kernel);

      xfsprogs = pkgs.fetchFromGitHub {
        owner = "alberand";
        repo = "xfsprogs";
        rev = "91bf9d98df8b50c56c9c297c0072a43b0ee02841";
        sha256 = "sha256-otEJr4PTXjX0AK3c5T6loLeX3X+BRBvCuDKyYcY9MQ4=";
      };
    };

    packages = rec {
      default = pkgs.vmtest;
      vmtest = pkgs.vmtest;
    };

    apps.default = flake-utils.lib.mkApp {
      drv = pkgs.vmtest;
    };
  });
}
