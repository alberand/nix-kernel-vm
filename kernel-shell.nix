let
  nix-kernel-vm = builtins.getFlake "github:alberand/nix-kernel-vm";
  system = "x86_64-linux";
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/24.05";
  pkgs = import nixpkgs {
    inherit system;
    config = {};
    overlays = [];
  };
  root = builtins.toString ./.;
  version = "6.9.0-rc4";
  src = builtins.fetchGit {
    url = /home/alberand/Projects/kernel/prj-quota-syscall;
    ref = "prj-quota-syscall";
    rev = "483109142e69f19e353fd582ac8ee18e1c643cd8";
    shallow = true;
  };
  configfile = nix-kernel-vm.lib.${system}.buildKernelConfig {
    inherit nixpkgs pkgs version src;
    structuredExtraConfig = with pkgs.lib.kernel; {
      CRYPTO_SHA256 = yes;
      QUOTA = yes;
      HID_CORSAIR = yes;
      LIBCRC32C = yes;
      XFS_FS = module;
      XFS_QUOTA = yes;
    };
  };
in
  nix-kernel-vm.lib.${system}.mkLinuxShell {
    inherit pkgs root;
    packages = [
      (pkgs.writeScriptBin "kernel-config" "cat ${configfile} > .config")
    ];

    user-config = {
      vm.disks = [5000 5000];
      environment.systemPackages = with pkgs; [
        btrfs-progs
        f2fs-tools
        keyutils
      ];
      boot.kernelParams = ["boot.shell_on_fail"];
      boot.kernelPackages = pkgs.linuxPackagesFor (
        nix-kernel-vm.lib.${system}.buildKernel {
          inherit nixpkgs version src configfile;
          modDirVersion = version;
        }
      );
      programs = {
        simple-test = {
          enable = true;
          test-dev = "/dev/vdb";
        };
        xfstests = {
          enable = false;
          src = builtins.fetchGit {
            url = /home/alberand/Projects/xfstests-dev;
            ref = "prj-quota-syscall";
            rev = "6713b3bd1a6486c2ef7b69348ab834f5f847b1e3";
            shallow = true;
          };
          testconfig = pkgs.fetchurl {
            url = "https://gist.githubusercontent.com/alberand/85fa4d7e0929902ef5d303ae1de5cc8a/raw/f42bc75660efbf03ec6ee4f31e70d632735aeeec/xfstests-config";
            hash = "sha256-dVNkh2FU1wSvPcIRAtFQryfQrKikyKMpbDCHHnvlMd0=";
          };
          test-dev = "/dev/vdb";
          scratch-dev = "/dev/vdc";
          arguments = "-s xfs_4k xfs/608";
          hooks = ./xfstests-hooks;
        };
        xfsprogs = {
          enable = true;
          src = builtins.fetchGit {
            url = /home/alberand/Projects/xfsprogs-dev;
            ref = "prj-quota-syscall";
            rev = "8bf13297861f1383b80e29da59c823dc0156c4c9";
            shallow = true;
          };
        };
      };
    };
  }
