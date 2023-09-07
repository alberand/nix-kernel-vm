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
    modules = [
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

          boot.kernelPackages = (pkgs.linuxPackagesFor (pkgs.callPackage pkgs.linuxManualConfig {
              inherit (pkgs) stdenv;
              version = "6.5.0-rc4";
              # ignoreConfigErrors = true;
              allowImportFromDerivation = true;
              src = pkgs.fetchFromGitHub {
                owner = "alberand";
                repo = "linux";
                rev = "17a940a32fd02da8e26ae984f0da9e73c1c163ab";
                sha256 = "sha256-3iyomhZPVv/EoBdMyrtfB74FOFfcg+w36OWNtMJKHiU=";
              };
              configfile = /home/alberand/Projects/xfs-verity-v3/.config;
              config = {
                CONFIG_AUTOFS4_FS = "y";
                CONFIG_VIRTIO_BLK = "y";
                CONFIG_VIRTIO_PCI = "y";
                CONFIG_VIRTIO_NET = "y";
                CONFIG_EXT4_FS = "y";
                CONFIG_NET_9P_VIRTIO = "y";
                CONFIG_9P_FS = "y";
                CONFIG_BLK_DEV = "y";
                CONFIG_PCI = "y";
                CONFIG_NETDEVICES = "y";
                CONFIG_NET_CORE = "y";
                CONFIG_INET = "y";
                CONFIG_NETWORK_FILESYSTEMS = "y";
                CONFIG_SERIAL_8250_CONSOLE = "y";
                CONFIG_SERIAL_8250 = "y";
                CONFIG_OVERLAY_FS = "y";
                CONFIG_DEVTMPFS = "y";
                CONFIG_CGROUPS = "y";
                CONFIG_SIGNALFD = "y";
                CONFIG_TIMERFD = "y";
                CONFIG_EPOLL = "y";
                CONFIG_SYSFS = "y";
                CONFIG_PROC_FS = "y";
                CONFIG_FHANDLE = "y";
                CONFIG_CRYPTO_USER_API_HASH = "y";
                CONFIG_CRYPTO_HMAC = "y";
                CONFIG_CRYPTO_SHA256 = "y";
                CONFIG_DMIID = "y";
                CONFIG_TMPFS_POSIX_ACL = "y";
                CONFIG_TMPFS_XATTR = "y";
                CONFIG_SECCOMP = "y";
                CONFIG_TMPFS = "y";
                CONFIG_BLK_DEV_INITRD = "y";
                CONFIG_MODULES = "y";
                CONFIG_BINFMT_ELF = "y";
                CONFIG_UNIX = "y";
                CONFIG_INOTIFY_USER = "y";
                CONFIG_NET = "y";
              };
          }));
          })
    ];
  in rec {
    lib = {
      mkVM = {
        pkgs,
        sharedir,
        qemu-options ? [],
        user-modules ? []
      }: nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          ./system.nix
          ({ config, pkgs, ...}: {
            virtualisation = {
              diskSize = 20000; # MB
              # Store the image in sharedir instead of pwd
              diskImage = "${sharedir}/test-node.qcow2";
              memorySize = 4096; # MB
              cores = 4;
              writableStoreUseTmpfs = false;
              useDefaultFilesystems = true;
              # Run qemu in the terminal not in Qemu GUI
              graphics = false;

              qemu = {
                options = [
                  "-device e1000,netdev=network0,mac=00:00:00:00:00:00"
                  "-netdev tap,id=network0,ifname=tap0,script=no,downscript=no"
                ] ++ qemu-options;
              };

              sharedDirectories = {
                results = {
                  source = "${sharedir}/results";
                  target = "/root/results";
                };
                vmtest = {
                  source = "${sharedir}";
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
            ./system.nix
          ] ++ user-modules;
          format = "iso";
        };
      };

      mkVmTest = {
        pkgs,
        sharedir,
        qemu-options ? [],
        user-modules ? []
      }:
      builtins.getAttr "vmtest" rec {
        nixos = lib.mkVM {
          inherit pkgs sharedir qemu-options user-modules;
        };

        vmtest = pkgs.writeScriptBin "vmtest"
        ((builtins.readFile ./run.sh) + ''
            ${nixos}/bin/run-test-node-vm
            echo "View results at $SHARE_DIR/results"
        '');
      };

      mkLinuxShell = {
        pkgs,
        root,
        sharedir ? "/tmp/vmtest",
        qemu-options ? [],
        user-modules ? [],
      }:
      builtins.getAttr "shell" rec {
        shell = pkgs.mkShell {
          packages = with pkgs; [
            (lib.mkVmTest {
              inherit pkgs sharedir qemu-options user-modules;
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

          SHARE_DIR = "${sharedir}";

          shellHook = ''
            if [ ! -f ${root}/compile_commands.json ] &&
                [ -f ${root}/scripts/clang-tools/gen_compile_commands.py ]; then
              ${root}/scripts/clang-tools/gen_compile_commands.py
            fi
          '';

        };
      };
    };

    devShells.default = lib.mkLinuxShell {
      inherit pkgs root;
      sharedir = "/tmp/sharedir";
      qemu-options = [
        "-hdc /dev/sdd4 -hdd /dev/sdd5 -serial mon:stdio"
      ];
      user-modules = modules;
    };

    packages = rec {
      default = vmtest;

      vmtest = lib.mkVmTest {
        inherit pkgs;
        sharedir = "/tmp/sharedir";
        qemu-options = [
          "-hdc /dev/sdd4 -hdd /dev/sdd5 -serial mon:stdio"
        ];
        user-modules = modules;
      };

      iso = lib.mkIso {
        inherit pkgs;
        user-modules = modules;
      };
    };

    apps.default = flake-utils.lib.mkApp {
      drv = packages.vmtest;
    };
  });
}
