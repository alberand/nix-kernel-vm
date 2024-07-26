{
  pkgs,
  nixos-generators,
  nixpkgs,
  ...
}: rec {
  mkVM = {
    pkgs,
    sharedir,
    qemu-options ? [],
    user-config ? {},
  }:
    nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      specialArgs = {diskSize = "20000";};
      modules = [
        ./xfstests.nix
        ./xfsprogs.nix
        ./simple-test.nix
        (pkgs.callPackage ./system.nix { inherit buildKernel buildKernelConfig nixpkgs; })
        ./vm.nix
        ({...}: user-config)
      ];
      format = "vm";
    };

  mkIso = {
    pkgs,
    test-disk,
    scratch-disk,
    user-config ? {},
  }:
    builtins.getAttr "iso" {
      iso = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          ./xfstests.nix
          ./xfsprogs.nix
          ./system.nix
          ({
            config,
            pkgs,
            ...
          }:
            {
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
            }
            // user-config)
        ];
        format = "iso";
      };
    };

  mkVmTest = {
    pkgs,
    sharedir ? "/tmp/vmtest",
    qemu-options ? [],
    user-config ? {},
  }:
    builtins.getAttr "vmtest" rec {
      nixos = mkVM {
        inherit pkgs sharedir qemu-options user-config;
      };

      vmtest =
        pkgs.writeScriptBin "vmtest"
        ((builtins.readFile ./run.sh)
          + ''
            ${nixos}/bin/run-test-node-vm 2>&1 | tee -a $LOG_FILE
            echo "View results at $SHARE_DIR/results"
            echo "Log is in $LOG_FILE"
          '');
    };

  mkLinuxShell = {
    pkgs,
    root,
    no-vm ? false,
    sharedir ? "/tmp/vmtest",
    qemu-options ? [],
    user-config ? {},
    packages ? [],
  }:
    builtins.getAttr "shell" {
      shell = pkgs.mkShell {
        packages =
          if no-vm
          then []
          else [
            (mkVmTest {
              inherit pkgs sharedir qemu-options user-config;
            })
            #(pkgs.writeScriptBin "kernel-config" ''
              #cat ${user-config.boot.kernelPackages.kernel.configfile} > new-config
              #echo "Wrote config to new-config. Run to use:"
              #echo "mv new-config .config"
            #'')
            (pkgs.writeScriptBin "kernel-build" ''
              if [ ! -f .config ]; then
                kernel-config
                mv new-config .config
              fi
              echo "Building Kernel"
              make -j$(nproc)
            '')
          ];

        nativeBuildInputs = with pkgs;
          [
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
            lld
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
            fio
            linuxquota
            nvme-cli
            virt-manager # for deploy
            xmlstarlet
            rpm
            pahole
            sphinx # for btrfs-progs
            zstd # for btrfs-progs
            udev # for btrfs-progs
            lzo # for btrfs-progs
            liburing # for btrfs-progs

            # probably better to move it to separate module
            smatch
            sqlite
            openssl
            libllvm
            libxml2.dev
            perl
            perl536Packages.DBI
            perl536Packages.DBDSQLite
            perl536Packages.TryTiny

            # kselftest deps
            libcap
            libcap_ng
            fuse3
            fuse
            alsa-lib
            libmnl
            numactl
          ]
          ++ packages;

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

          if type -p ccache; then
            export KBUILD_BUILD_TIMESTAMP=""
            alias make='make CC="ccache gcc"'
          fi
        '';
      };
    };

  buildKernelConfig = pkgs.callPackage ./kernel-config.nix {};
  buildKernel = pkgs.callPackage ./kernel.nix {};

  deploy = {pkgs}:
    builtins.getAttr "script" {
      script = pkgs.writeScriptBin "deploy" (builtins.readFile ./deploy.sh);
    };
}
