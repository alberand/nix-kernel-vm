{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fetch-lore.url = "github:dramforever/fetch-lore";
    nixos-generators.url = "github:nix-community/nixos-generators";
  };

  outputs = { self, nixpkgs, flake-utils, fetch-lore, nixos-generators, pkgs }:
  flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
  let
    pkgs = import nixpkgs {
      inherit system;
    };
    # default kernel if no custom kernel were specified
    root = builtins.toString ./.;
  in rec {
    lib = {
      mkSys = {
        pkgs,
        sharepoint,
        user-modules ? []
      }: nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            ./vm.nix
            ({ config, pkgs, ...}: {
              virtualisation = {
                diskSize = 20000; # MB
                # Store the image in sharepoint instead of pwd
                diskImage = "${sharepoint}/vm.qcow2";
                memorySize = 4096; # MB
                cores = 4;
                writableStoreUseTmpfs = false;
                useDefaultFilesystems = true;
                # Run qemu in the terminal not in Qemu GUI
                graphics = false;

                qemu = {
                  networkingOptions = [
                    "-device e1000,netdev=network0,mac=00:00:00:00:00:00"
                    "-netdev tap,id=network0,ifname=tap0,script=no,downscript=no"
                  ];
                };

                sharedDirectories = {
                  results = {
                    source = "${sharepoint}/results";
                    target = "/root/results";
                  };
                  vmtest = {
                    source = "${sharepoint}";
                    target = "/root/vmtest";
                  };
                };
              };
            })
          ] ++ user-modules;
          format = "vm";
        };

      mkIso = {
        pkgs,
        user-modules ? []
      }:
      builtins.getAttr "iso" {
        iso = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          modules = [
            ./vm.nix
          ] ++ user-modules;
          format = "iso";
        };
      };

      mkVmTest = {
        pkgs,
        sharepoint,
        user-modules ? []
      }:
      builtins.getAttr "vmtest" rec {
        nixos = lib.mkSys {
          inherit pkgs sharepoint user-modules;
        };

        vmtest = pkgs.writeScriptBin "vmtest"
        ((builtins.readFile ./run.sh) + ''
            ${nixos}/bin/run-vm-vm
            echo "View results at $SHARE_DIR/results"
        '');
      };

      mkVmSystem = {
        pkgs,
        user-modules ? [],
      }: builtins.getAttr "vm-system" rec {
        nixos = lib.mkSys {
          inherit pkgs user-modules;
          sharepoint = "/tmp/vmtest";
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
        sharepoint ? "/tmp/vmtest",
        user-modules ? [],
        vm-system ? null,
      }:
      builtins.getAttr "shell" rec {
        nixos = lib.mkSys {
          inherit pkgs sharepoint user-modules;
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
              inherit pkgs sharepoint user-modules;
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

    devShells.default = lib.mkLinuxShell {
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
            arguments = "-s xfs_4k generic/001 generic/002";
          };

          # Let's also include specific version of xfsprogs
          nixpkgs.overlays = [
            (self: super: {
              xfsprogs = super.xfsprogs.overrideAttrs ({
                version = "git";
                src = pkgs.fetchFromGitHub {
                  owner = "alberand";
                  repo = "xfsprogs";
                  rev = "12ee5324c60e5394b4d8a2b58726a4aadfaf0ac9";
                  sha256 = "sha256-pWfBo6MHmiCTB172NFLdD/oNEih0ntLrM6NIQIVXD80=";
                };
              });
            })
          ];

          # Let's append real hardware to the QEMU run by "vmtest" command
          virtualisation = {
            qemu = {
              networkingOptions = [
                "-hdc /dev/sdc4 -hdd /dev/sdc5 -serial mon:stdio"
              ];
            };
          };
          # Let's specify kernel we want our VM to be built with
          #boot.kernelPackages = let
          #  linux-custom = { fetchurl, buildLinux, ... } @ args:
          #  buildLinux (args // rec {
          #    version = "6.4.0-rc3";
          #    modDirVersion = version;

          #    src = fetchurl {
          #      url = "https://git.kernel.org/torvalds/t/linux-6.4-rc3.tar.gz";
          #      sha256 = "sha256-xlN7KcrtykVG3W9DDbODKNKJehGCAQOr4R2uw3hfxoE=";
          #    };

          #    extraConfig = ''
          #    '';
          #  } // (args.argsOverride or {}));
          #  kernel = pkgs.callPackage linux-custom {};
          #in
          #  pkgs.recurseIntoAttrs (pkgs.linuxPackagesFor kernel);
        })
      ];
    };

    packages = rec {
      default = vmtest;
      vmtest = lib.mkVmTest {
        inherit pkgs;
        sharepoint = "/tmp/vmtest";
        user-modules = [
          ({config, pkgs, ...}: {
          programs.xfstests = {
            enable = true;
            src = pkgs.fetchFromGitHub {
              owner = "alberand";
              repo = "xfstests";
              rev = "068d7af36369c7c3da7d165c50b378e7b7ce46fd";
              sha256 = "sha256-okVvdUG7ixDm7awquBvLQmN4qGma4DFM8vSJ/4VJoL0=";
            };
            autoshutdown = false;
            testconfig = ./xfstests.config;
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
                  rev = "12ee5324c60e5394b4d8a2b58726a4aadfaf0ac9";
                  sha256 = "sha256-pWfBo6MHmiCTB172NFLdD/oNEih0ntLrM6NIQIVXD80=";
                };
              });
            })
          ];

          # Let's append real hardware to the QEMU run by "vmtest" command
          virtualisation = {
            qemu = {
              networkingOptions = [
                "-hdc /dev/sdc4 -hdd /dev/sdc5 -serial mon:stdio"
              ];
            };
          };
          })
        ];
      };
      iso = lib.mkIso {
        inherit pkgs;
        user-modules = [
          ({config, pkgs, ...}: {
          programs.xfstests = {
            enable = true;
            src = pkgs.fetchFromGitHub {
              owner = "alberand";
              repo = "xfstests";
              rev = "068d7af36369c7c3da7d165c50b378e7b7ce46fd";
              sha256 = "sha256-okVvdUG7ixDm7awquBvLQmN4qGma4DFM8vSJ/4VJoL0=";
            };
            autoshutdown = false;
            testconfig = ./xfstests.config;
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
                  rev = "12ee5324c60e5394b4d8a2b58726a4aadfaf0ac9";
                  sha256 = "sha256-pWfBo6MHmiCTB172NFLdD/oNEih0ntLrM6NIQIVXD80=";
                };
              });
            })
          ];
        })
        ];
      };
    };

    apps.default = flake-utils.lib.mkApp {
      drv = packages.vmtest;
    };
  });
}
