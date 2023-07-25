{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fetch-lore.url = "github:dramforever/fetch-lore";
    nixos-generators.url = "github:nix-community/nixos-generators";
  };

  outputs = { self, nixpkgs, flake-utils, fetch-lore, nixos-generators, pkgs }:
  flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = import nixpkgs { inherit system; };
    # default kernel if no custom kernel were specified
    kernel-default = pkgs.linuxPackages_6_1;
    root = builtins.toString ./.;
  in rec {
    lib = {
      mkSys = {
        pkgs,
        kernel-custom ? kernel-default,
        user-modules ? []
      }: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./vm.nix
        ] ++ user-modules;
      };

      mkIso = {
        pkgs,
        user-modules ? []
      }:
      {
        iso = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            ./vm.nix
          ] ++ user-modules;
          format = "iso";
        };
      }

      mkVmTest = {
        pkgs,
        kernel-custom ? kernel-default,
        user-modules ? []
      }:
      builtins.getAttr "vmtest" rec {
        #pkgs = import nixpkgs { inherit system; };
        nixos = lib.mkSys {
          inherit pkgs kernel-custom user-modules;
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

      mkVmSystem = {
        pkgs,
        user-modules ? [],
      }: builtins.getAttr "vm-system" rec {
        nixos = lib.mkSys {
          inherit user-modules;
        };

        vm-system = if vm-system then vm-system else pkgs.symlinkJoin {
          name = "vm-system";
          paths = with nixos.config.system.build; [
            vm
            kernel
          ];
          preferLocalBuild = true;
        };
      };

      mkLinuxShell = {
        pkgs,
        root,
        kernel-custom ? kernel-default,
        user-modules ? [],
        vm-system ? null,
      }:
      builtins.getAttr "shell" rec {
        nixos = lib.mkSys {
          inherit pkgs user-modules;
        };

        vm-system = if vm-system then vm-system else pkgs.symlinkJoin {
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
              inherit pkgs kernel-custom user-modules;
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

        } // {
          vm = nixos;
        };
      };
    };

    pkgs.vmtest = let
      pkgs = import nixpkgs { inherit system; };
    in lib.mkVmTest {
      inherit pkgs;

      };

    pkgs.iso = let
      pkgs = import nixpkgs { inherit system; };
    in lib.mkIso {
      inherit pkgs;

      };

      devShells.default = let
        pkgs = import nixpkgs { inherit system; };
      in lib.mkLinuxShell {
        inherit pkgs root;
        user-modules = [
          ({config, pkgs, ...}: {

            # Just a test user to check that our modules are enabled
          users.users.hahaha-andrey = {
            isNormalUser  = true;
            description  = "hahaha-andrey user";
          };

          # Let's enable xfstests service
            programs.xfstests = {
              enable = true;
              src = pkgs.fetchFromGitHub {
                owner = "alberand";
                repo = "xfstests";
                rev = "2500effc2c77939343161304bf436dfd58c73735";
                sha256 = "sha256-XxtFm7a+NRvv8xzaVMBWe+B0BtLZLoNGH6IlGbTu4NE=";
              };
              autoshutdown = false;
              testconfig = ./xfstests.config;
              arguments = "-g xfs_4k generic/001";
            };

            # Let's also include specific version of xfsprogs
            nixpkgs.overlays = [
              (self: super: {
                xfsprogs = super.xfsprogs.overrideAttrs (prev: {
                  version = "git";
                  src = pkgs.fetchFromGitHub {
                    owner = "alberand";
                    repo = "xfsprogs";
                    rev = "86a672f111328fc16e8ea5524498020b0c1152a8";
                    sha256 = "sha256-XwKSp9ilEehseCoIvLRkjcdfTaIfpAHyHnlayDs5fO8=";
                  };
                });
              })
            ];

            # Let's append real hardware to the QEMU run by "vmtest" command
            virtualisation = {
              qemu = {
                networkingOptions = [
                  "-hdc /dev/sdb4 -hdd /dev/sdb5 -serial mon:stdio"
                ];
              };
            };

            # Let's specify kernel we want our VM to be built with
            boot.kernelPackages = let
              linux-custom = { fetchurl, buildLinux, ... } @ args:
              buildLinux (args // rec {
                version = "6.4.0-rc3";
                modDirVersion = version;

                src = fetchurl {
                  url = "https://git.kernel.org/torvalds/t/linux-6.4-rc3.tar.gz";
                  sha256 = "sha256-xlN7KcrtykVG3W9DDbODKNKJehGCAQOr4R2uw3hfxoE=";
                };
                kernelPatches = [
                  {
                    name = "XFS altered mount string";
                    patch = /home/alberand/Projects/linux/patches/0001-test-custom-kernel-version-with-altered-XFS-mount-st.patch;
                  }
                ];

                extraConfig = ''
                '';
              } // (args.argsOverride or {}));
              kernel = pkgs.callPackage linux-custom {};
            in
              pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor kernel);
          })
        ];

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
