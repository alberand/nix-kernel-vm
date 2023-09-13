{
  description = "VM for filesystem testing of Linux Kernel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fetch-lore.url = "github:dramforever/fetch-lore";
    nixos-generators.url = "github:nix-community/nixos-generators";
    kernel-config.url = "/home/alberand/Projects/xfs-verity-v3/.config";
    kernel-config.flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, fetch-lore, nixos-generators,
      kernel-config, pkgs }:
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
                rev = "f8768339be4e978deca688cd2225bf4d49bcc78e";
                sha256 = "sha256-Rc4Phs/6k5YVpoQeIeqPiKlSHW5uTAOsUtEpG6FEDnM=";
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
            rev = "17a940a32fd02da8e26ae984f0da9e73c1c163ab";
            sha256 = "sha256-3iyomhZPVv/EoBdMyrtfB74FOFfcg+w36OWNtMJKHiU=";
          };
          configfile = kernel-config;
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
    lib = import ./lib.nix {
      inherit pkgs nixos-generators;
    };

    devShells.default = lib.mkLinuxShell {
      inherit pkgs root;
      sharedir = "/tmp/vmtest";
      qemu-options = [
        "-hdc /dev/sdd4 -hdd /dev/sdd5 -serial mon:stdio"
      ];
      user-modules = modules;
    };

    packages = rec {
      default = vmtest;

      vmtest = lib.mkVmTest {
        inherit pkgs;
        sharedir = "/tmp/vmtest";
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
