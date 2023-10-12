{pkgs, nixos-generators, ...}:
rec {
  mkVM = {
    pkgs,
    sharedir,
    qemu-options ? [],
    user-modules ? []
  }: nixos-generators.nixosGenerate {
    system = "x86_64-linux";
    modules = [
      ./xfstests.nix
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
              "-device virtio-rng-pci"
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
    test-disk,
    scratch-disk,
    user-modules ? []
  }: builtins.getAttr "iso" {
    iso = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [
        ./xfstests.nix
        ./system.nix
        ({ config, pkgs, ... }: {
          # Don't shutdown system as libvirtd will remove the VM
          programs.xfstests.autoshutdown = false;

          fileSystems."/mnt/test" = {
            device = test-disk;
            fsType = "xfs";
            autoFormat = true;
            label = "test";
          };

          fileSystems."/mnt/scratch" = {
            device = scratch-disk;
            fsType = "xfs";
            autoFormat = true;
            label = "scratch";
          };
        })
      ] ++ user-modules;
      format = "iso";
    };
  };

  mkVmTest = {
    pkgs,
    sharedir ? "/tmp/vmtest",
    qemu-options ? [],
    user-modules ? []
  }:
  builtins.getAttr "vmtest" rec {
    nixos = mkVM {
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
    no-vm ? false,
    sharedir ? "/tmp/vmtest",
    qemu-options ? [],
    user-modules ? [],
    packages ? [],
  }:
  builtins.getAttr "shell" rec {
    shell = pkgs.mkShell {
      packages = if no-vm then [] else [
        (mkVmTest {
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
        jq
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
        xmlstarlet
      ] ++ packages;

      buildInputs = with pkgs; [
        elfutils
        ncurses
        openssl
        zlib
      ];

      SHARE_DIR = "${sharedir}";

      shellHook = ''
        curdir="$(pwd)"
        if [ ! -f "$curdir/compile_commands.json" ] &&
            [ -f "$curdir/scripts/clang-tools/gen_compile_commands.py" ]; then
          "$curdir/scripts/clang-tools/gen_compile_commands.py"
        fi
      '';
    };
  };

  deploy = { pkgs }:
  builtins.getAttr "script" rec {
    script = pkgs.writeScriptBin "deploy" (builtins.readFile ./deploy.sh);
  };
}
